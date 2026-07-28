package io.airo.platform_text_embeddings

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.text.textembedder.TextEmbedder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.RejectedExecutionException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.sqrt

class PlatformTextEmbeddingsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private val lifecycleLock = Any()
    private val sessions = mutableMapOf<String, NativeEmbeddingSession>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var attached = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        synchronized(lifecycleLock) {
            applicationContext = binding.applicationContext
            attached = true
        }
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        when (call.method) {
            "initialize" -> initialize(call.arguments, result)
            "embed" -> embed(call.arguments, result)
            "close" -> close(call.arguments, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(
        rawArguments: Any?,
        result: MethodChannel.Result,
    ) {
        val arguments = rawArguments as? Map<*, *>
        val modelPath = arguments?.get("modelPath") as? String
        val model = arguments?.get("model") as? Map<*, *>
        val dimensions =
            EmbeddingRequestValidator.exactDimensions(model?.get("dimensions"))
        val expectedSha256 = model?.get("sha256") as? String
        val context = synchronized(lifecycleLock) {
            if (attached) applicationContext else null
        }
        if (
            context == null ||
            modelPath.isNullOrBlank() ||
            dimensions == null ||
            expectedSha256 == null
        ) {
            result.success(PlatformReplies.failure(EmbeddingFailure.INVALID_INPUT))
            return
        }
        if (!EmbeddingRequestValidator.isSupportedDimensions(dimensions)) {
            result.success(
                PlatformReplies.failure(EmbeddingFailure.UNSUPPORTED_DIMENSIONS),
            )
            return
        }
        if (!EmbeddingRequestValidator.isSha256(expectedSha256)) {
            result.success(PlatformReplies.failure(EmbeddingFailure.INVALID_INPUT))
            return
        }

        val executor = newSessionExecutor()
        executor.execute {
            val modelFile = sandboxedFile(context, modelPath)
            if (modelFile == null || !modelFile.isFile) {
                executor.shutdown()
                respond(
                    result,
                    PlatformReplies.failure(EmbeddingFailure.MODEL_MISSING),
                )
                return@execute
            }
            if (!matchesSha256(modelFile, expectedSha256)) {
                executor.shutdown()
                respond(
                    result,
                    PlatformReplies.failure(
                        EmbeddingFailure.MODEL_INTEGRITY_MISMATCH,
                    ),
                )
                return@execute
            }

            var embedder: TextEmbedder? = null
            try {
                val baseOptions =
                    BaseOptions
                        .builder()
                        .setModelAssetPath(modelFile.absolutePath)
                        .build()
                val options =
                    TextEmbedder.TextEmbedderOptions
                        .builder()
                        .setBaseOptions(baseOptions)
                        .setL2Normalize(true)
                        .setQuantize(false)
                        .build()
                embedder = TextEmbedder.createFromOptions(context, options)
                val probe = embeddingValues(embedder, INITIALIZATION_PROBE)
                if (probe == null || probe.size != dimensions) {
                    closeQuietly(embedder)
                    executor.shutdown()
                    respond(
                        result,
                        PlatformReplies.failure(
                            EmbeddingFailure.UNSUPPORTED_DIMENSIONS,
                        ),
                    )
                    return@execute
                }
                if (!isUnitVector(probe)) {
                    closeQuietly(embedder)
                    executor.shutdown()
                    respond(
                        result,
                        PlatformReplies.failure(
                            EmbeddingFailure.INITIALIZATION_FAILED,
                        ),
                    )
                    return@execute
                }

                val sessionId = UUID.randomUUID().toString()
                val session =
                    NativeEmbeddingSession(
                        dimensions = dimensions,
                        embedder = embedder,
                        executor = executor,
                    )
                embedder = null
                val installed = synchronized(lifecycleLock) {
                    if (attached) {
                        sessions[sessionId] = session
                        true
                    } else {
                        false
                    }
                }
                if (!installed) {
                    session.closeAsync()
                    respond(
                        result,
                        PlatformReplies.failure(EmbeddingFailure.CANCELLED),
                    )
                    return@execute
                }
                respond(result, PlatformReplies.ready(sessionId))
            } catch (_: Exception) {
                closeQuietly(embedder)
                executor.shutdown()
                respond(
                    result,
                    PlatformReplies.failure(
                        EmbeddingFailure.INITIALIZATION_FAILED,
                    ),
                )
            }
        }
    }

    private fun embed(
        rawArguments: Any?,
        result: MethodChannel.Result,
    ) {
        val arguments = rawArguments as? Map<*, *>
        val sessionId = arguments?.get("sessionId") as? String
        val text = arguments?.get("text") as? String
        if (sessionId.isNullOrBlank() || text == null) {
            result.success(PlatformReplies.failure(EmbeddingFailure.INVALID_INPUT))
            return
        }
        val session = synchronized(lifecycleLock) { sessions[sessionId] }
        if (session == null) {
            result.success(
                PlatformReplies.failure(EmbeddingFailure.PROVIDER_CLOSED),
            )
            return
        }
        session.embed(text) { response -> respond(result, response) }
    }

    private fun close(
        rawArguments: Any?,
        result: MethodChannel.Result,
    ) {
        val arguments = rawArguments as? Map<*, *>
        val sessionId = arguments?.get("sessionId") as? String
        if (sessionId.isNullOrBlank()) {
            result.success(PlatformReplies.failure(EmbeddingFailure.INVALID_INPUT))
            return
        }
        val session = synchronized(lifecycleLock) { sessions.remove(sessionId) }
        if (session == null) {
            result.success(PlatformReplies.closed())
            return
        }
        session.closeAsync { respond(result, PlatformReplies.closed()) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        val activeSessions = synchronized(lifecycleLock) {
            attached = false
            applicationContext = null
            sessions.values.toList().also { sessions.clear() }
        }
        activeSessions.forEach { session -> session.closeAsync() }
    }

    private fun respond(
        result: MethodChannel.Result,
        response: Map<String, Any>,
    ) {
        mainHandler.post { result.success(response) }
    }

    companion object {
        private const val CHANNEL_NAME =
            "dev.airo.platform_text_embeddings/methods"
        private const val INITIALIZATION_PROBE =
            "Airo local embedding initialization probe."
    }
}

private class NativeEmbeddingSession(
    private val dimensions: Int,
    private val embedder: TextEmbedder,
    private val executor: ExecutorService,
) {
    private val closed = AtomicBoolean(false)

    fun embed(
        text: String,
        callback: (Map<String, Any>) -> Unit,
    ) {
        if (closed.get()) {
            callback(
                PlatformReplies.failure(EmbeddingFailure.PROVIDER_CLOSED),
            )
            return
        }
        try {
            executor.execute {
                if (closed.get()) {
                    callback(
                        PlatformReplies.failure(
                            EmbeddingFailure.PROVIDER_CLOSED,
                        ),
                    )
                    return@execute
                }
                if (!EmbeddingRequestValidator.isValidText(text)) {
                    callback(
                        PlatformReplies.failure(EmbeddingFailure.INVALID_INPUT),
                    )
                    return@execute
                }
                try {
                    val values = embeddingValues(embedder, text)
                    if (
                        values == null ||
                        values.size != dimensions ||
                        !isUnitVector(values)
                    ) {
                        callback(
                            PlatformReplies.failure(
                                EmbeddingFailure.INFERENCE_FAILED,
                            ),
                        )
                        return@execute
                    }
                    callback(
                        PlatformReplies.success(values.map { it.toDouble() }),
                    )
                } catch (_: Exception) {
                    callback(
                        PlatformReplies.failure(
                            EmbeddingFailure.INFERENCE_FAILED,
                        ),
                    )
                }
            }
        } catch (_: RejectedExecutionException) {
            callback(
                PlatformReplies.failure(EmbeddingFailure.PROVIDER_CLOSED),
            )
        }
    }

    fun closeAsync(onClosed: (() -> Unit)? = null) {
        if (!closed.compareAndSet(false, true)) {
            onClosed?.invoke()
            return
        }
        try {
            executor.execute {
                try {
                    embedder.close()
                } finally {
                    executor.shutdown()
                    onClosed?.invoke()
                }
            }
        } catch (_: RejectedExecutionException) {
            executor.shutdown()
            onClosed?.invoke()
        }
    }
}

private fun embeddingValues(
    embedder: TextEmbedder,
    text: String,
): FloatArray? =
    embedder
        .embed(text)
        .embeddingResult()
        .embeddings()
        .firstOrNull()
        ?.floatEmbedding()

private fun closeQuietly(embedder: TextEmbedder?) {
    if (embedder == null) return
    try {
        embedder.close()
    } catch (_: Exception) {
        // Cleanup failure must not suppress the stable failure response.
    }
}

private fun isUnitVector(values: FloatArray): Boolean {
    var normSquared = 0.0
    for (value in values) {
        if (!value.isFinite()) return false
        normSquared += value.toDouble() * value.toDouble()
    }
    if (!normSquared.isFinite() || normSquared == 0.0) return false
    return abs(sqrt(normSquared) - 1.0) <= 1e-3
}

private fun sandboxedFile(
    context: Context,
    modelPath: String,
): File? {
    return try {
        val sandbox = context.dataDir.canonicalFile
        val candidate = File(modelPath).canonicalFile
        if (
            candidate.path == sandbox.path ||
            candidate.path.startsWith("${sandbox.path}${File.separator}")
        ) {
            candidate
        } else {
            null
        }
    } catch (_: Exception) {
        null
    }
}

private fun matchesSha256(
    file: File,
    expectedSha256: String,
): Boolean {
    return try {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                digest.update(buffer, 0, count)
            }
        }
        val actual =
            digest.digest().joinToString(separator = "") { byte ->
                "%02x".format(byte)
            }
        actual.equals(expectedSha256, ignoreCase = true)
    } catch (_: Exception) {
        false
    }
}

private fun newSessionExecutor(): ExecutorService =
    Executors.newSingleThreadExecutor { runnable ->
        Thread(runnable, "airo-text-embedding").apply {
            isDaemon = true
        }
    }
