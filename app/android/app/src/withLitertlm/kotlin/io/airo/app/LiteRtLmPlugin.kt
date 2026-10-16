package io.airo.app

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.EmbeddingEngine
import com.google.ai.edge.litertlm.EmbeddingEngineConfig
import com.google.ai.edge.litertlm.EmbeddingOptions
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.InputData
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.ExperimentalFlags
import com.google.ai.edge.litertlm.Message
import com.google.ai.edge.litertlm.ModelInfo
import com.google.ai.edge.litertlm.OpenApiTool
import com.google.ai.edge.litertlm.tool
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONArray
import org.json.JSONObject

/**
 * Flutter MethodChannel bridge for LiteRT-LM.
 *
 * The Dart side owns feature routing and fallback behavior. This native bridge
 * loads a local .litertlm/.task model, keeps one conversation so the KV cache
 * survives follow-up turns, and accepts an optional image file for multimodal
 * packages Google already ships quantized.
 */
@OptIn(ExperimentalApi::class)
class LiteRtLmPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LiteRtLmPlugin"
        private const val HTTP_RANGE_NOT_SATISFIABLE = 416
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var engine: Engine? = null
    private var conversation: Conversation? = null
    private var conversationSystemPrompt: String? = null
    private var conversationMaxTokens: Int? = null
    private var conversationToolKey: String? = null
    private var initializedModelPath: String? = null
    private var visionEnabled: Boolean = false
    private var installedModelPath: String? = null
    private var embeddingEngine: EmbeddingEngine? = null
    private var embeddingModelPath: String? = null
    private val streamHandler = LiteRtLmStreamHandler()

    fun getStreamHandler(): EventChannel.StreamHandler = streamHandler

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> isAvailable(call, result)
            "initialize" -> initialize(call, result)
            "generateContent" -> generateContent(call, result)
            "generateContentStream" -> generateContentStream(call, result)
            "describeModel" -> describeModel(call, result)
            "installModel" -> installModel(call, result)
            "embedInitialize" -> embedInitialize(call, result)
            "embedReady" -> result.success(embeddingEngine?.isInitialized == true)
            "embedText" -> embedText(call, result)
            "embedMedia" -> embedMedia(call, result)
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(call: MethodCall, result: MethodChannel.Result) {
        val modelPath = call.argument<String>("modelPath") ?: installedModelPath
        result.success(!modelPath.isNullOrBlank() && File(modelPath).exists())
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val modelPath = call.argument<String>("modelPath") ?: installedModelPath
                    ?: throw IllegalArgumentException("modelPath is required")
                val backendName = call.argument<String>("backend") ?: "gpu"
                val enableVision = call.argument<Boolean>("vision") ?: false

                withContext(Dispatchers.IO) {
                    if (initializedModelPath == modelPath &&
                        engine != null &&
                        visionEnabled == enableVision
                    ) {
                        return@withContext
                    }

                    closeActiveEngine()

                    if (backendName.equals("gpu", ignoreCase = true)) {
                        // MTP is the recommended GPU decode path for the
                        // quantized Gemma 4 packages.
                        ExperimentalFlags.enableSpeculativeDecoding = true
                    }

                    val backend = backendFromName(backendName)
                    val config = if (enableVision) {
                        EngineConfig(
                            modelPath = modelPath,
                            backend = backend,
                            cacheDir = context.cacheDir.path,
                            visionBackend = Backend.GPU(),
                        )
                    } else {
                        EngineConfig(
                            modelPath = modelPath,
                            backend = backend,
                            cacheDir = context.cacheDir.path,
                        )
                    }
                    val newEngine = Engine(config)
                    newEngine.initialize()
                    engine = newEngine
                    initializedModelPath = modelPath
                    visionEnabled = enableVision
                }

                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM initialization failed: ${e.message}", e)
                result.error("INITIALIZATION_FAILED", e.message, null)
            }
        }
    }

    private fun installModel(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val url = call.argument<String>("url")
                    ?: throw IllegalArgumentException("url is required")
                val huggingFaceToken = call.argument<String>("huggingFaceToken")

                val path = withContext(Dispatchers.IO) {
                    val destination = modelDestination(url)
                    if (!destination.exists() || destination.length() == 0L) {
                        destination.parentFile?.mkdirs()
                        downloadToFile(url, destination, huggingFaceToken)
                    }
                    installedModelPath = destination.absolutePath
                    destination.absolutePath
                }

                result.success(path)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM model installation failed: ${e.message}", e)
                result.error("INSTALLATION_FAILED", e.message, null)
            }
        }
    }

    private fun generateContent(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val toolResponses = parseToolResponses(call)
                val tools = parseTools(call)
                val prompt = call.argument<String>("prompt")
                    ?: if (toolResponses.isEmpty()) {
                        throw IllegalArgumentException("prompt is required")
                    } else {
                        ""
                    }
                val systemPrompt = call.argument<String>("systemPrompt")
                val imagePath = call.argument<String>("imagePath")
                val maxTokens = call.argument<Int>("maxTokens") ?: 2048
                val reuseConversation = call.argument<Boolean>("reuseConversation") ?: true

                val response = withContext(Dispatchers.IO) {
                    val activeEngine = engine
                        ?: throw IllegalStateException("LiteRT-LM engine is not initialized")

                    if (!reuseConversation) {
                        // Warmup must not leave a draft turn in the session
                        // cache, and the engine keeps one live conversation.
                        clearConversation()
                        val oneShot = createConversation(
                            activeEngine,
                            systemPrompt,
                            maxTokens.takeIf { it > 0 },
                            tools,
                        )
                        try {
                            sendTurn(oneShot, prompt, imagePath, toolResponses)
                        } finally {
                            oneShot.close()
                        }
                    } else {
                        val activeConversation = conversationFor(
                            activeEngine,
                            systemPrompt,
                            maxTokens,
                            tools,
                        )
                        sendTurn(activeConversation, prompt, imagePath, toolResponses)
                    }
                }

                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM generation failed: ${e.message}", e)
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }

    private fun generateContentStream(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val prompt = call.argument<String>("prompt")
                    ?: throw IllegalArgumentException("prompt is required")
                val systemPrompt = call.argument<String>("systemPrompt")
                val imagePath = call.argument<String>("imagePath")
                val maxTokens = call.argument<Int>("maxTokens") ?: 2048
                val reuseConversation = call.argument<Boolean>("reuseConversation") ?: true

                withContext(Dispatchers.IO) {
                    val activeEngine = engine
                        ?: throw IllegalStateException("LiteRT-LM engine is not initialized")
                    val activeConversation = if (!reuseConversation) {
                        clearConversation()
                        createConversation(
                            activeEngine,
                            systemPrompt?.takeIf { it.isNotBlank() },
                            maxTokens.takeIf { it > 0 },
                        )
                    } else {
                        conversationFor(activeEngine, systemPrompt, maxTokens, emptyList())
                    }
                    try {
                        streamConversation(activeConversation, prompt, imagePath)
                    } finally {
                        if (!reuseConversation) {
                            activeConversation.close()
                        }
                    }
                }
                withContext(Dispatchers.Main) {
                    streamHandler.endStream()
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM streaming failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    streamHandler.sendError(e.message ?: "LiteRT-LM streaming failed")
                }
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }

    private suspend fun streamConversation(
        activeConversation: Conversation,
        prompt: String,
        imagePath: String?,
    ) {
        var snapshot = ""
        activeConversation.sendMessageAsync(promptContents(prompt, imagePath)).collect { message ->
            val rendered = activeConversation.renderMessageIntoString(message)
            snapshot = mergeStreamText(snapshot, rendered)
            if (snapshot.isNotEmpty()) {
                val chunk = snapshot
                withContext(Dispatchers.Main) {
                    streamHandler.sendChunk(chunk)
                }
            }
        }
    }

    private fun describeModel(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val modelPath = call.argument<String>("modelPath") ?: installedModelPath
                    ?: throw IllegalArgumentException("modelPath is required")
                val described = withContext(Dispatchers.IO) {
                    val info = ModelInfo.from(modelPath)
                    try {
                        val modalities = info.inputModalities()
                        val payload = hashMapOf<String, Any?>(
                            "modelType" to info.modelType.name,
                            "maxContextTokens" to info.maxContextTokens(),
                            "maxVisionTokenBudget" to info.maxVisionTokenBudget(),
                            "dynamicContext" to info.isDynamicContext(),
                            "text" to modalities.text,
                            "vision" to modalities.vision,
                            "audio" to modalities.audio,
                            "video" to modalities.video,
                            "functionCalling" to false,
                            "thinking" to false,
                            "speculativeDecoding" to false,
                        )
                        val llm = info as? ModelInfo.Llm
                        if (llm != null) {
                            payload["functionCalling"] = llm.supportsFunctionCalling()
                            payload["thinking"] = llm.supportsThinking()
                            payload["speculativeDecoding"] = llm.hasSpeculativeDecodingSupport()
                        }
                        payload
                    } finally {
                        info.close()
                    }
                }
                result.success(described)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM model description failed: ${e.message}", e)
                result.error("DESCRIBE_FAILED", e.message, null)
            }
        }
    }

    private fun conversationFor(
        engine: Engine,
        systemPrompt: String?,
        maxTokens: Int,
        tools: List<OpenApiTool>,
    ): Conversation {
        val normalizedPrompt = systemPrompt?.takeIf { it.isNotBlank() }
        val tokenBudget = maxTokens.takeIf { it > 0 }
        val toolKey = toolKey(tools)
        val existing = conversation
        if (existing != null &&
            conversationSystemPrompt == normalizedPrompt &&
            conversationMaxTokens == tokenBudget &&
            conversationToolKey == toolKey
        ) {
            return existing
        }
        existing?.close()
        val created = createConversation(engine, normalizedPrompt, tokenBudget, tools)
        conversation = created
        conversationSystemPrompt = normalizedPrompt
        conversationMaxTokens = tokenBudget
        conversationToolKey = toolKey
        return created
    }

    private fun createConversation(
        engine: Engine,
        systemPrompt: String?,
        maxTokens: Int?,
        tools: List<OpenApiTool> = emptyList(),
    ): Conversation {
        if (systemPrompt == null && maxTokens == null && tools.isEmpty()) {
            return engine.createConversation()
        }
        if (tools.isEmpty()) {
            val config = when {
                systemPrompt == null -> ConversationConfig(maxOutputToken = maxTokens)
                maxTokens == null -> ConversationConfig(
                    systemInstruction = Contents.of(systemPrompt),
                )
                else -> ConversationConfig(
                    systemInstruction = Contents.of(systemPrompt),
                    maxOutputToken = maxTokens,
                )
            }
            return engine.createConversation(config)
        }
        // The app executes lookup tools. Leaving automatic calling on would
        // run OpenApiTool.execute inside the native runtime instead.
        return engine.createConversation(
            ConversationConfig(
                systemInstruction = systemPrompt?.let { Contents.of(it) },
                tools = tools.map { tool(it) },
                automaticToolCalling = false,
                maxOutputToken = maxTokens?.takeIf { it > 0 },
            ),
        )
    }

    private fun sendTurn(
        activeConversation: Conversation,
        prompt: String,
        imagePath: String?,
        toolResponses: List<Pair<String, String>>,
    ): HashMap<String, Any?> {
        val message = if (toolResponses.isNotEmpty()) {
            val contents = toolResponses.map { (name, response) ->
                Content.ToolResponse(name, response)
            }
            activeConversation.sendMessage(Message.tool(Contents.of(contents)))
        } else {
            activeConversation.sendMessage(promptContents(prompt, imagePath))
        }
        val calls = ArrayList<HashMap<String, Any?>>()
        for (call in message.toolCalls) {
            calls.add(
                hashMapOf(
                    "name" to call.name,
                    "arguments" to codecValue(call.arguments),
                ),
            )
        }
        return hashMapOf(
            "text" to activeConversation.renderMessageIntoString(message),
            "toolCalls" to calls,
        )
    }

    private fun parseTools(call: MethodCall): List<OpenApiTool> {
        val raw = call.argument<List<*>>("tools") ?: return emptyList()
        val tools = ArrayList<OpenApiTool>()
        for (item in raw) {
            val map = item as? Map<*, *> ?: continue
            val name = map["name"]?.toString()?.trim().orEmpty()
            if (name.isEmpty()) continue
            val spec = JSONObject()
            spec.put("name", name)
            spec.put("description", map["description"]?.toString().orEmpty())
            spec.put("parameters", jsonValue(map["parameters"]) ?: JSONObject())
            tools.add(DescribedOpenApiTool(spec.toString()))
        }
        return tools
    }

    private fun parseToolResponses(call: MethodCall): List<Pair<String, String>> {
        val raw = call.argument<List<*>>("toolResponses") ?: return emptyList()
        val responses = ArrayList<Pair<String, String>>()
        for (item in raw) {
            val map = item as? Map<*, *> ?: continue
            val name = map["name"]?.toString()?.trim().orEmpty()
            if (name.isEmpty()) continue
            responses.add(name to (map["response"]?.toString() ?: ""))
        }
        return responses
    }

    private fun toolKey(tools: List<OpenApiTool>): String {
        return tools.joinToString("\n") { it.getToolDescriptionJsonString() }
    }

    private fun jsonValue(value: Any?): Any? {
        return when (value) {
            null -> null
            is Map<*, *> -> JSONObject().apply {
                for ((key, nested) in value) {
                    put(key.toString(), jsonValue(nested))
                }
            }
            is List<*> -> JSONArray().apply {
                for (nested in value) {
                    put(jsonValue(nested))
                }
            }
            is String, is Number, is Boolean -> value
            else -> value.toString()
        }
    }

    private fun codecValue(value: Any?): Any? {
        return when (value) {
            null, is String, is Boolean, is Int, is Long, is Double -> value
            is Float -> value.toDouble()
            is Number -> value.toDouble()
            is Map<*, *> -> HashMap<String, Any?>().apply {
                for ((key, nested) in value) {
                    put(key.toString(), codecValue(nested))
                }
            }
            is List<*> -> ArrayList<Any?>().apply {
                for (nested in value) {
                    add(codecValue(nested))
                }
            }
            else -> value.toString()
        }
    }

    private fun clearConversation() {
        conversation?.close()
        conversation = null
        conversationSystemPrompt = null
        conversationMaxTokens = null
        conversationToolKey = null
    }

    private fun promptContents(prompt: String, imagePath: String?): Contents {
        if (imagePath.isNullOrBlank()) {
            return Contents.of(prompt)
        }
        val imageFile = File(imagePath)
        if (!imageFile.isFile) {
            throw IllegalArgumentException("imagePath is not a file")
        }
        return Contents.of(
            Content.ImageFile(imagePath),
            Content.Text(prompt),
        )
    }

    private fun mergeStreamText(previous: String, rendered: String): String {
        if (rendered.isEmpty()) return previous
        if (previous.isEmpty()) return rendered
        if (rendered.startsWith(previous)) return rendered
        if (previous.endsWith(rendered)) return previous
        return previous + rendered
    }

    private fun backendFromName(name: String): Backend {
        return when (name.lowercase()) {
            "cpu" -> Backend.CPU()
            "npu" -> Backend.NPU(nativeLibraryDir = context.applicationInfo.nativeLibraryDir)
            else -> Backend.GPU()
        }
    }

    private fun modelDestination(url: String): File {
        val rawName = url.substringAfterLast('/').substringBefore('?')
        val safeName = rawName
            .takeIf { it.isNotBlank() }
            ?.replace(Regex("[^A-Za-z0-9._-]"), "_")
            ?: "litert_lm_model.task"
        return File(File(context.filesDir, "litert_lm_models"), safeName)
    }

    private fun downloadToFile(url: String, destination: File, huggingFaceToken: String?) {
        val partial = File("${destination.absolutePath}.part")
        val offset = if (partial.exists()) partial.length() else 0L
        var connection = openDownloadConnection(url, offset, huggingFaceToken)
        var append = offset > 0L && connection.responseCode == HttpURLConnection.HTTP_PARTIAL
        if (offset > 0L && connection.responseCode == HTTP_RANGE_NOT_SATISFIABLE) {
            // The server no longer has the requested range (for example after
            // a model was replaced). Discard the stale partial and restart
            // cleanly instead of retrying the same impossible range forever.
            connection.disconnect()
            partial.delete()
            connection = openDownloadConnection(url, 0L, huggingFaceToken)
            append = false
        }
        if (!append) {
            partial.delete()
        }

        try {
            BufferedInputStream(connection.inputStream).use { input ->
                FileOutputStream(partial, append).use { output ->
                    input.copyTo(output)
                    output.fd.sync()
                }
            }
        } finally {
            connection.disconnect()
        }

        if (!partial.exists() || partial.length() == 0L) {
            throw IllegalStateException("LiteRT-LM download produced an empty artifact")
        }
        if (destination.exists() && !destination.delete()) {
            throw IllegalStateException("Could not replace the existing LiteRT-LM artifact")
        }
        if (!partial.renameTo(destination)) {
            throw IllegalStateException("Could not finalize the LiteRT-LM artifact")
        }
    }

    private fun openDownloadConnection(
        url: String,
        offset: Long,
        huggingFaceToken: String?,
    ): HttpURLConnection {
        val connection = URL(url).openConnection() as HttpURLConnection
        connection.connectTimeout = 30_000
        connection.readTimeout = 120_000
        if (offset > 0L) {
            connection.setRequestProperty("Range", "bytes=$offset-")
        }
        if (!huggingFaceToken.isNullOrBlank()) {
            connection.setRequestProperty("Authorization", "Bearer $huggingFaceToken")
        }
        return connection
    }

    private fun embedInitialize(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val modelPath = call.argument<String>("modelPath")
                    ?: throw IllegalArgumentException("modelPath is required")
                val useGpu = call.argument<Boolean>("useGpu") ?: false
                withContext(Dispatchers.IO) {
                    if (embeddingModelPath == modelPath &&
                        embeddingEngine?.isInitialized == true
                    ) {
                        return@withContext
                    }
                    embeddingEngine?.close()
                    val backend = if (useGpu) Backend.GPU() else Backend.CPU()
                    // 512 is one of EmbeddingGemma 2's published input lengths
                    // and matches short search queries and meeting chunks.
                    val created = EmbeddingEngine(
                        EmbeddingEngineConfig(
                            modelPath = modelPath,
                            backend = backend,
                            cacheDir = context.cacheDir.path,
                            maxInputLength = 512,
                        ),
                    )
                    created.initialize()
                    embeddingEngine = created
                    embeddingModelPath = modelPath
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM embedding init failed: ${e.message}", e)
                embeddingEngine?.close()
                embeddingEngine = null
                embeddingModelPath = null
                result.error("EMBEDDING_FAILED", e.message, null)
            }
        }
    }

    private fun embedText(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val text = call.argument<String>("text")
                    ?: throw IllegalArgumentException("text is required")
                val vector = withContext(Dispatchers.IO) {
                    val engine = embeddingEngine
                        ?: throw IllegalStateException("Embedding model is not initialized")
                    val response = engine.computeEmbedding(
                        listOf(InputData.Text(text)),
                        EmbeddingOptions(normalize = true),
                    )
                    response.embedding.map { it.toDouble() }
                }
                result.success(vector)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM embedding failed: ${e.message}", e)
                result.error("EMBEDDING_FAILED", e.message, null)
            }
        }
    }

    private fun embedMedia(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val imagePath = call.argument<String>("imagePath")
                val audioPath = call.argument<String>("audioPath")
                val vector = withContext(Dispatchers.IO) {
                    val engine = embeddingEngine
                        ?: throw IllegalStateException("Embedding model is not initialized")
                    val input = when {
                        !imagePath.isNullOrBlank() -> {
                            val file = File(imagePath)
                            if (!file.isFile) {
                                throw IllegalArgumentException("imagePath is not a file")
                            }
                            InputData.Image(file.readBytes())
                        }
                        !audioPath.isNullOrBlank() -> {
                            val file = File(audioPath)
                            if (!file.isFile) {
                                throw IllegalArgumentException("audioPath is not a file")
                            }
                            InputData.Audio(file.readBytes())
                        }
                        else -> throw IllegalArgumentException(
                            "imagePath or audioPath is required",
                        )
                    }
                    engine.computeEmbedding(
                        listOf(input),
                        EmbeddingOptions(normalize = true),
                    ).embedding.map { it.toDouble() }
                }
                result.success(vector)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM media embedding failed: ${e.message}", e)
                result.error("EMBEDDING_FAILED", e.message, null)
            }
        }
    }

    private fun closeActiveEngine() {
        clearConversation()
        engine?.close()
        engine = null
        initializedModelPath = null
        visionEnabled = false
        embeddingEngine?.close()
        embeddingEngine = null
        embeddingModelPath = null
    }
}

private class DescribedOpenApiTool(
    private val descriptionJson: String,
) : OpenApiTool {
    override fun getToolDescriptionJsonString(): String = descriptionJson

    override fun execute(args: String): String {
        return """{"error":"tool_execution_deferred"}"""
    }
}

private class LiteRtLmStreamHandler : EventChannel.StreamHandler {
    private var eventSink: EventChannel.EventSink? = null
    private val pendingChunks = mutableListOf<String>()
    private var ended = false
    private var pendingError: String? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        pendingChunks.forEach { events?.success(it) }
        pendingChunks.clear()
        val error = pendingError
        if (error != null) {
            events?.error("GENERATION_FAILED", error, null)
            pendingError = null
            ended = false
            return
        }
        if (ended) {
            events?.endOfStream()
            ended = false
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun sendChunk(chunk: String) {
        val sink = eventSink
        if (sink == null) {
            pendingChunks.add(chunk)
        } else {
            sink.success(chunk)
        }
    }

    fun sendError(message: String) {
        val sink = eventSink
        if (sink == null) {
            pendingError = message
        } else {
            sink.error("GENERATION_FAILED", message, null)
        }
    }

    fun endStream() {
        val sink = eventSink
        if (sink == null) {
            ended = true
        } else {
            sink.endOfStream()
        }
    }
}
