package io.airo.app

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Wraps the receiver-side streaming engine for the
 * com.airo.player/streaming_engine channel (SPEC.md AD-1/AD-5, Phase 2).
 *
 * `ping` only for now -- proves the channel round-trips before any Media3
 * wiring exists. Registered unconditionally like every other plugin in
 * this file: there is no separate tv Kotlin source set to gate this by
 * (see build.gradle.kts's isTvVariant, which only gates manifest/res and
 * packaging excludes), so an idle handler on phone/Coins builds is the
 * same cost every other plugin here already pays.
 */
class AiroStreamingEnginePlugin {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/streaming_engine"
    }

    private var channel: MethodChannel? = null

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success(true)
                else -> result.notImplemented()
            }
        }
        this.channel = channel
    }
}
