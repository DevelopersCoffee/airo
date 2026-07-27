package io.airo.app

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
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

    private fun buildParams(autoEnter: Boolean): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(autoEnter)
        }
        return builder.build()
    }

    fun notifyModeChanged(isInPip: Boolean) {
        channel?.invokeMethod("pictureInPictureStateChanged", isInPip)
    }
}
