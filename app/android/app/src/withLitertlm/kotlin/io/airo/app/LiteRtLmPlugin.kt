package io.airo.app

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.ai.edge.litertlm.Backend
import com.google.ai.edge.litertlm.Contents
import com.google.ai.edge.litertlm.Conversation
import com.google.ai.edge.litertlm.ConversationConfig
import com.google.ai.edge.litertlm.Engine
import com.google.ai.edge.litertlm.EngineConfig
import com.google.ai.edge.litertlm.ExperimentalApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedInputStream
import java.io.File
import java.net.URL

/**
 * Flutter MethodChannel bridge for LiteRT-LM.
 *
 * The Dart side owns feature routing and fallback behavior. This native bridge
 * only loads a local .litertlm/.task model and runs single-turn prompts.
 */
@OptIn(ExperimentalApi::class)
class LiteRtLmPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "LiteRtLmPlugin"
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var engine: Engine? = null
    private var initializedModelPath: String? = null
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

                withContext(Dispatchers.IO) {
                    if (initializedModelPath == modelPath && engine != null) return@withContext

                    closeActiveEngine()

                    val config = EngineConfig(
                        modelPath = modelPath,
                        backend = backendFromName(backendName),
                        cacheDir = context.cacheDir.path
                    )
                    val newEngine = Engine(config)
                    newEngine.initialize()
                    engine = newEngine
                    initializedModelPath = modelPath
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

                val response = withContext(Dispatchers.IO) {
                    val activeEngine = engine
                        ?: throw IllegalStateException("LiteRT-LM engine is not initialized")

                    createConversation(activeEngine, systemPrompt).use { activeConversation ->
                        val message = activeConversation.sendMessage(prompt)
                        activeConversation.renderMessageIntoString(message)
                    }
                }

                result.success(response)
            } catch (e: Exception) {
                Log.e(TAG, "LiteRT-LM generation failed: ${e.message}", e)
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }

    private fun createConversation(engine: Engine, systemPrompt: String?): Conversation {
        if (systemPrompt.isNullOrBlank()) {
            return engine.createConversation()
        }

        val config = ConversationConfig(
            systemInstruction = Contents.of(systemPrompt)
        )
        return engine.createConversation(config)
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
        val connection = URL(url).openConnection()
        connection.connectTimeout = 30_000
        connection.readTimeout = 120_000
        if (!huggingFaceToken.isNullOrBlank()) {
            connection.setRequestProperty("Authorization", "Bearer $huggingFaceToken")
        }

        BufferedInputStream(connection.getInputStream()).use { input ->
            destination.outputStream().use { output ->
                input.copyTo(output)
            }
        }
    }

    private fun closeActiveEngine() {
        engine?.close()
        engine = null
        initializedModelPath = null
    }
}
