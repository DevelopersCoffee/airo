package io.airo.app

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Wraps PictureInPictureParams for the com.airo.player/picture_in_picture channel. */
class AiroPictureInPicturePlugin(private val activity: Activity) {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/picture_in_picture"
    }

    private var channel: MethodChannel? = null

    /** When true, the app wants PiP on user-leave (Home press) while playing. */
    private var autoEnterArmed = false

    /**
     * The video surface's current on-screen bounds (physical pixels), kept
     * in sync by the Flutter side on every frame. Restricts the system PiP
     * snapshot to just the video via [PictureInPictureParams.Builder.setSourceRectHint] --
     * without it Android snapshots the whole Activity window, capturing
     * whatever chrome (channel list, app bar, dialogs) is visible the
     * instant PiP is entered.
     */
    private var sourceRectHint: Rect? = null

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "requestEnter" -> result.success(requestEnter())
                "setAutoEnterEnabled" -> {
                    setAutoEnterEnabled(call.argument<Boolean>("enabled") ?: false)
                    result.success(null)
                }
                "setSourceRectHint" -> {
                    updateSourceRectHint(call.argument<List<Int>>("rect"))
                    result.success(null)
                }
                "isActive" -> result.success(activity.isInPictureInPictureMode)
                else -> result.notImplemented()
            }
        }
        this.channel = channel
    }

    private fun isSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun requestEnter(): Boolean {
        if (!isSupported()) return false
        return activity.enterPictureInPictureMode(buildParams(autoEnter = false))
    }

    /**
     * Arms/disarms system-driven PiP entry. On API 31+ this sets the Activity's
     * PictureInPictureParams with autoEnterEnabled so Home-press enters PiP while
     * the Activity is still resumed; on API 26–30 the flag is consumed by
     * [onUserLeaveHint] instead.
     */
    private fun setAutoEnterEnabled(enabled: Boolean) {
        autoEnterArmed = enabled
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && isSupported()) {
            activity.setPictureInPictureParams(buildParams(autoEnter = enabled))
        }
    }

    /**
     * Called from MainActivity.onUserLeaveHint, which fires on Home press while
     * the Activity is still resumed — the only safe point to enter PiP on
     * API 26–30. Dart-driven entry (AppLifecycleState.paused) is always too
     * late: enterPictureInPictureMode() requires a resumed Activity. API 31+
     * relies on autoEnterEnabled and deliberately does not double-enter here.
     */
    fun onUserLeaveHint() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) return
        if (autoEnterArmed) requestEnter()
    }

    /**
     * Called from Flutter on every frame the video surface builds. Only
     * stores the rect -- [buildParams] reads it whenever [requestEnter] or
     * [setAutoEnterEnabled] next runs, which is already how every other
     * params field (aspect ratio, autoEnter) reaches the system. Proactively
     * calling `setPictureInPictureParams` here as well was redundant and, on
     * device, correlated with auto-enter PiP silently no-longer triggering
     * on Home press -- removed rather than risk that regression for a hint
     * that's purely cosmetic (crops the snapshot) and not required to be
     * live between real params-applying calls.
     */
    private fun updateSourceRectHint(rect: List<Int>?) {
        if (rect == null || rect.size != 4) return
        val next = Rect(rect[0], rect[1], rect[2], rect[3])
        if (next.isEmpty) return
        sourceRectHint = next
    }

    private fun buildParams(autoEnter: Boolean): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        sourceRectHint?.let { builder.setSourceRectHint(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }
        return builder.build()
    }

    fun notifyModeChanged(isInPip: Boolean) {
        channel?.invokeMethod("pictureInPictureStateChanged", isInPip)
    }
}
