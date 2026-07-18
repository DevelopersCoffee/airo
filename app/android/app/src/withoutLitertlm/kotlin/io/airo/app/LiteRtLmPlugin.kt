package io.airo.app

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Stub replacement for the real LiteRT-LM plugin, compiled in when the
 * `com.google.ai.edge.litertlm:litertlm-android` dependency is not
 * available (CI validation builds and unauthenticated clones — see
 * `app/android/build.gradle.kts` `liteRtLmAvailable`).
 *
 * The Dart side (`app/lib/core/services/litert_lm_service.dart`) treats
 * `isAvailable → false` as "no LiteRT-LM" and falls back to the ML Kit
 * GenAI path, so every method here reports the feature as unavailable
 * instead of throwing.
 */
class LiteRtLmPlugin(@Suppress("UNUSED_PARAMETER") private val context: Context) :
    MethodChannel.MethodCallHandler {
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(false)
            "initialize", "generateContent", "installModel" ->
                result.error(
                    "LITERTLM_UNAVAILABLE",
                    "LiteRT-LM is not linked in this build.",
                    null,
                )
            else -> result.notImplemented()
        }
    }
}
