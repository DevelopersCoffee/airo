package io.airo.app

import android.content.Context
import androidx.annotation.NonNull
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Stub compiled for Fire TV builds that omit ML Kit GenAI Prompt (GMS-only).
 */
class GeminiNanoPlugin(@Suppress("UNUSED_PARAMETER") private val context: Context) :
    MethodChannel.MethodCallHandler {

    fun getStreamHandler(): EventChannel.StreamHandler =
        object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {}

            override fun onCancel(arguments: Any?) {}
        }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(false)
            "getDeviceInfo", "getMemoryInfo", "getCapabilities" ->
                result.success(emptyMap<String, Any>())
            else ->
                result.error(
                    "GEMINI_NANO_UNAVAILABLE",
                    "ML Kit GenAI Prompt is not linked in this build.",
                    null,
                )
        }
    }
}
