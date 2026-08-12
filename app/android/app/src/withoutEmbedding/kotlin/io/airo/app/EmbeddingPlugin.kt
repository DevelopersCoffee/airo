package io.airo.app

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Stub replacement for the real embedding plugin, compiled in when
 * `com.google.ai.edge.localagents:localagents-rag` is not available
 * (`AIRO_USE_EMBEDDING_STUB=true` -- see `app/android/build.gradle.kts`).
 *
 * The Dart side (`EmbeddingService`, `core_ai`) treats `isReady -> false` as
 * "no embedding model available" and falls back to keyword-only search
 * (`SemanticSearchRanker`), so every method here reports the feature as
 * unavailable instead of throwing.
 */
class EmbeddingPlugin(@Suppress("UNUSED_PARAMETER") private val context: Context) :
    MethodChannel.MethodCallHandler {
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isReady" -> result.success(false)
            "initialize", "embed" ->
                result.error(
                    "EMBEDDING_UNAVAILABLE",
                    "The embedding plugin is not linked in this build.",
                    null,
                )
            else -> result.notImplemented()
        }
    }
}
