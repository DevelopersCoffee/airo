package io.airo.app

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Content
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import com.google.ai.edge.litertlm.ExperimentalFlags
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.FileOutputStream
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

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
    private var initializedModelPath: String? = null
    private var visionEnabled: Boolean = false
    private var installedModelPath: String? = null

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> isAvailable(call, result)
            "initialize" -> initialize(call, result)
            "generateContent" -> generateContent(call, result)
            "installModel" -> installModel(call, result)
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
                val prompt = call.argument<String>("prompt")
                    ?: throw IllegalArgumentException("prompt is required")
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
                        conversation?.close()
                        conversation = null
                        conversationSystemPrompt = null
                        conversationMaxTokens = null
                        val oneShot = createConversation(
                            activeEngine,
                            systemPrompt,
                            maxTokens.takeIf { it > 0 },
                        )
                        try {
                            sendPrompt(oneShot, prompt, imagePath)
                        } finally {
                            oneShot.close()
                        }
                    } else {
                        val activeConversation = conversationFor(
                            activeEngine,
                            systemPrompt,
                            maxTokens,
                        )
                        sendPrompt(activeConversation, prompt, imagePath)
                    }
                }

                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM generation failed: ${e.message}", e)
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }

    private fun conversationFor(
        engine: Engine,
        systemPrompt: String?,
        maxTokens: Int,
    ): Conversation {
        val normalizedPrompt = systemPrompt?.takeIf { it.isNotBlank() }
        val tokenBudget = maxTokens.takeIf { it > 0 }
        val existing = conversation
        if (existing != null &&
            conversationSystemPrompt == normalizedPrompt &&
            conversationMaxTokens == tokenBudget
        ) {
            return existing
        }
        existing?.close()
        val created = createConversation(engine, normalizedPrompt, tokenBudget)
        conversation = created
        conversationSystemPrompt = normalizedPrompt
        conversationMaxTokens = tokenBudget
        return created
    }

    private fun createConversation(
        engine: Engine,
        systemPrompt: String?,
        maxTokens: Int?,
    ): Conversation {
        if (systemPrompt == null && maxTokens == null) {
            return engine.createConversation()
        }
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

    private fun sendPrompt(
        activeConversation: Conversation,
        prompt: String,
        imagePath: String?,
    ): String {
        val message = if (imagePath.isNullOrBlank()) {
            activeConversation.sendMessage(prompt)
        } else {
            val imageFile = File(imagePath)
            if (!imageFile.isFile) {
                throw IllegalArgumentException("imagePath is not a file")
            }
            activeConversation.sendMessage(
                Contents.of(
                    Content.ImageFile(imagePath),
                    Content.Text(prompt),
                ),
            )
        }
        return activeConversation.renderMessageIntoString(message)
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

    private fun closeActiveEngine() {
        conversation?.close()
        conversation = null
        conversationSystemPrompt = null
        conversationMaxTokens = null
        engine?.close()
        engine = null
        initializedModelPath = null
        visionEnabled = false
    }
}
