package io.airo.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Method channel for Spatial Mode PCM tap status and mode (#2081). */
class AiroSpatialAudioPlugin {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/spatial_audio"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "spatialAudioTapStatus" -> result.success(AiroSpatialPcmTap.tapStatusMap())
                "setSpatialAudioMode" -> {
                    val mode = call.argument<String>("mode") ?: "original"
                    AiroSpatialPcmTap.setSpatialAudioMode(mode)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
