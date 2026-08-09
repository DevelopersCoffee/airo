package io.airo.app

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.ai.edge.localagents.rag.models.GeckoEmbeddingModel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.Optional

/**
 * Flutter MethodChannel bridge for on-device text embeddings, via Google's
 * AI Edge RAG SDK (`GeckoEmbeddingModel`).
 *
 * A separate plugin from `LiteRtLmPlugin.kt` on purpose: EmbeddingGemma is
 * not published as a `.litertlm` package (raw `.tflite` + a
 * `sentencepiece.model` tokenizer instead), so it needs a different loader
 * and a different SDK entirely
 * (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
 *
 * VERIFICATION NEEDED before this ships: `GeckoEmbeddingModel`'s embed-call
 * method name/signature below (`computeEmbeddings`) is inferred from the AI
 * Edge RAG SDK's `Embedder<String>` interface convention (a
 * `ListenableFuture`-returning async call, per Google's published samples
 * for this SDK family) -- the public Android integration guide did not show
 * a direct code sample for extracting a vector, only the constructor. Check
 * this against the actual `com.google.ai.edge.localagents:localagents-rag`
 * AAR's public API (e.g. via Android Studio's decompiled sources or the
 * SDK's own javadoc) before merging. If the real method differs, only this
 * one call site needs to change -- everything else in this file (channel
 * contract, lifecycle, error handling) does not depend on the exact name.
 */
class EmbeddingPlugin(private val context: Context) : MethodChannel.MethodCallHandler {
    companion object {
        private const val TAG = "EmbeddingPlugin"
    }

    private val coroutineScope = CoroutineScope(Dispatchers.Main)
    private var embedder: GeckoEmbeddingModel? = null

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "initialize" -> initialize(call, result)
            "isReady" -> result.success(embedder != null)
            "embed" -> embed(call, result)
            else -> result.notImplemented()
        }
    }

    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val modelPath = call.argument<String>("modelPath")
                    ?: throw IllegalArgumentException("modelPath is required")
                val tokenizerPath = call.argument<String>("tokenizerPath")
                    ?: throw IllegalArgumentException("tokenizerPath is required")
                val useGpu = call.argument<Boolean>("useGpu") ?: false

                withContext(Dispatchers.IO) {
                    embedder = GeckoEmbeddingModel(
                        modelPath,
                        Optional.of(tokenizerPath),
                        useGpu,
                    )
                }

                result.success(null)
            } catch (e: Exception) {
                Log.e(TAG, "Embedding model initialization failed: ${e.message}", e)
                embedder = null
                result.error("INITIALIZATION_FAILED", e.message, null)
            }
        }
    }

    private fun embed(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                val text = call.argument<String>("text")
                    ?: throw IllegalArgumentException("text is required")

                val vector = withContext(Dispatchers.IO) {
                    val activeEmbedder = embedder
                        ?: throw IllegalStateException("Embedding model is not initialized")
                    // See the class doc: this call needs verification against
                    // the real AAR before shipping.
                    activeEmbedder.computeEmbeddings(text).get()
                }

                result.success(vector.toList())
            } catch (e: Exception) {
                Log.e(TAG, "Embedding generation failed: ${e.message}", e)
                result.error("EMBEDDING_FAILED", e.message, null)
            }
        }
    }
}
