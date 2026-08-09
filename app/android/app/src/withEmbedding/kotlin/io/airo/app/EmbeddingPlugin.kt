package io.airo.app

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import com.google.ai.edge.localagents.rag.models.EmbedData
import com.google.ai.edge.localagents.rag.models.EmbeddingRequest
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
 * The `getEmbeddings(EmbeddingRequest<String>)` call below was confirmed
 * against the real `com.google.ai.edge.localagents:localagents-rag:0.1.0`
 * AAR (`javap` on its decompiled `classes.jar`, on a Pixel 9 build attempt)
 * -- the first version of this file guessed `computeEmbeddings(text)`,
 * which failed `compileDebugKotlin` with "Unresolved reference." `TaskType`
 * is `SEMANTIC_SIMILARITY` for every call: the SDK also offers
 * `RETRIEVAL_QUERY`/`RETRIEVAL_DOCUMENT` for asymmetric query-vs-document
 * encoding, which would improve search quality, but this plugin's
 * `embed(text)` channel method doesn't yet distinguish a query from a
 * document -- that's a real refinement for whoever builds
 * `SemanticSearchRanker` (Phase 3), not invented here.
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
                    val request = EmbeddingRequest.create(
                        listOf(EmbedData.create(text, EmbedData.TaskType.SEMANTIC_SIMILARITY)),
                    )
                    activeEmbedder.getEmbeddings(request).get()
                }

                result.success(vector.toList())
            } catch (e: Exception) {
                Log.e(TAG, "Embedding generation failed: ${e.message}", e)
                result.error("EMBEDDING_FAILED", e.message, null)
            }
        }
    }
}
