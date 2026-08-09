package io.airo.app

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Wraps the receiver-side streaming engine for the
 * com.airo.player/streaming_engine method and event channels (SPEC.md
 * AD-1/AD-5, Phase 2).
 *
 * `ping` proves the method channel round-trips. [notifyPhase] forwards
 * native playback-phase transitions to the Dart state stream
 * (`AiroStreamingEngineState.phaseStream`) -- the real (tv) streaming
 * surface factory calls this from its Media3 `Player.Listener`; the stub
 * factory on other variants never does, so the event channel simply never
 * emits there. Registered unconditionally like every other plugin in this
 * file, same reasoning as the method channel above.
 */
class AiroStreamingEnginePlugin {
    companion object {
        const val CHANNEL_NAME = "com.airo.player/streaming_engine"
        const val STATE_EVENT_CHANNEL_NAME = "com.airo.player/streaming_engine/state"
    }

    private var channel: MethodChannel? = null
    private var stateEventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    fun register(messenger: BinaryMessenger) {
        val channel = MethodChannel(messenger, CHANNEL_NAME)
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ping" -> result.success(true)
                "preWarm" -> {
                    AiroStreamingEngine.preWarm(call.argument<List<String>>("hosts") ?: emptyList())
                    result.success(null)
                }
                "shadowFetch" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("INVALID_ARGUMENT", "url is required", null)
                    } else {
                        // AiroShadowFetch.probe() does a blocking OkHttp call --
                        // Android forbids network I/O on the main thread
                        // (NetworkOnMainThreadException, confirmed on a real
                        // device, not hypothetical). MethodChannel.Result must
                        // be resolved back on the main thread, so post the
                        // result after the background call returns rather
                        // than resolving from the background thread directly.
                        Thread {
                            val outcome = AiroStreamingEngine.shadowFetch(url)
                            mainHandler.post { result.success(outcome) }
                        }.start()
                    }
                }
                "switchSource" -> {
                    val url = call.argument<String>("url")
                    if (url == null) {
                        result.error("INVALID_ARGUMENT", "url is required", null)
                    } else {
                        result.success(AiroStreamingEngine.switchSource(url))
                    }
                }
                else -> result.notImplemented()
            }
        }
        this.channel = channel

        EventChannel(messenger, STATE_EVENT_CHANNEL_NAME).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    stateEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    stateEventSink = null
                }
            },
        )
    }

    /** Forwards a native playback phase's stableId (e.g. "playing", "buffering"). */
    fun notifyPhase(phaseStableId: String) {
        stateEventSink?.success(phaseStableId)
    }
}
