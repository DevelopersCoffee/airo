package io.airo.app

import android.app.Activity
import android.os.Build
import android.view.Display
import android.view.Surface
import android.view.Window
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Lets Dart ask the window for a high refresh rate.
 *
 * Android often leaves third-party apps on 60 Hz until the window sets
 * [WindowManager.LayoutParams.preferredDisplayModeId]. The mode itself is
 * chosen in Dart ([AiroFramePacePolicy]) so the rule is unit-tested once.
 * This plugin is compiled into every product source set, including Coins
 * and Anya, which replace `src/product/kotlin`.
 */
class AiroFramePacePlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val window = activity?.window
        if (window == null) {
            result.error("no_activity", "Frame pace needs a resumed activity", null)
            return
        }
        when (call.method) {
            "getModes" -> result.success(AiroFramePaceModes.read(window))
            "applyMode" -> {
                val id = call.argument<Int>("id")
                if (id == null) {
                    result.error("bad_args", "id is required", null)
                    return
                }
                result.success(AiroFramePaceModes.apply(window, id))
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL = "dev.developerscoffee.airo/frame_pace"

        fun register(engine: FlutterEngine) {
            if (!engine.plugins.has(AiroFramePacePlugin::class.java)) {
                engine.plugins.add(AiroFramePacePlugin())
            }
        }
    }
}

internal object AiroFramePaceModes {
    fun read(window: Window): Map<String, Any?> {
        val display = currentDisplay(window)
            ?: return mapOf("supported" to emptyList<Map<String, Any>>(), "active" to null)
        return mapOf(
            "supported" to display.supportedModes.map { it.toMap() },
            "active" to display.mode.toMap(),
        )
    }

    fun apply(window: Window, modeId: Int): Boolean {
        val display = currentDisplay(window) ?: return false
        val mode = display.supportedModes.firstOrNull { it.modeId == modeId } ?: return false
        val attrs = window.attributes
        if (attrs.preferredDisplayModeId != modeId) {
            attrs.preferredDisplayModeId = modeId
            window.attributes = attrs
        }
        hintFrameRate(window, mode.refreshRate)
        return true
    }

    private fun hintFrameRate(window: Window, refreshRate: Float) {
        if (Build.VERSION.SDK_INT < 35) return
        try {
            window.setFrameRate(
                refreshRate,
                Surface.FRAME_RATE_COMPATIBILITY_DEFAULT,
                Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS,
            )
        } catch (ignored: RuntimeException) {
            // preferredDisplayModeId is already set. The seamless hint is
            // optional and some OEM windows reject it before attach.
        }
    }

    @Suppress("DEPRECATION")
    private fun currentDisplay(window: Window): Display? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.context.display
        } else {
            window.windowManager.defaultDisplay
        }
    }

    private fun Display.Mode.toMap(): Map<String, Any> {
        return mapOf(
            "id" to modeId,
            "width" to physicalWidth,
            "height" to physicalHeight,
            "refreshRate" to refreshRate.toDouble(),
        )
    }
}
