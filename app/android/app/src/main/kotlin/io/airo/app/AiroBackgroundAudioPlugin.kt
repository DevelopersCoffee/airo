package io.airo.app

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Wraps AudioManager focus handling for the com.airo.player/background_audio_mode channel. */
class AiroBackgroundAudioPlugin(private val context: Context) {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/background_audio_mode"
    }

    private val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private var focusRequest: AudioFocusRequest? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "setEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setEnabled(enabled)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun setEnabled(enabled: Boolean) {
        if (enabled) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_MEDIA)
                .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                .build()
            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(attributes)
                .build()
            audioManager.requestAudioFocus(request)
            focusRequest = request
        } else {
            focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
            focusRequest = null
        }
        // Media-session metadata (title, playback state) for the lock-screen
        // control surface is already driven by the app's existing
        // audio_service/AudioServiceActivity integration (MainActivity
        // extends AudioServiceActivity); this plugin only owns audio focus,
        // not notification building, to avoid a second competing media
        // session.
    }
}
