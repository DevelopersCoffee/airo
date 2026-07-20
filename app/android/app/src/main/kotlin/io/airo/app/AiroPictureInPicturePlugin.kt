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

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isSupported" -> result.success(isSupported())
                "requestEnter" -> result.success(requestEnter())
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
        val params = PictureInPictureParams.Builder()
            .setAspectRatio(Rational(16, 9))
            .build()
        return activity.enterPictureInPictureMode(params)
    }

    fun notifyModeChanged(isInPip: Boolean) {
        channel?.invokeMethod("pictureInPictureStateChanged", isInPip)
    }
}
