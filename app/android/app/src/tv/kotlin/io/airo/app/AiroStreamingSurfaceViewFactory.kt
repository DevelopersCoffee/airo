package io.airo.app

import android.content.Context
import android.util.Log
import android.view.SurfaceView
import android.view.View
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.analytics.AnalyticsListener
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.exoplayer.source.LoadEventInfo
import androidx.media3.exoplayer.source.MediaLoadData
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Receiver surface (SPEC.md AD-1/AD-5, Phase 2). Started as a Wave A
 * proof-of-concept with Media3's stock `DataSource`; now plays through
 * [AiroStreamingEngine]'s custom `DataSource` (Wave B, F4.1/F4.2 --
 * resolver cache + pooled/tuned connections) while still targeting one
 * hardcoded public HLS test stream -- Wave C's failover/ranking is what
 * turns "one hardcoded stream" into "the channel's ranked source list."
 *
 * Hosts a bare [SurfaceView]; Flutter PlatformView -> Kotlin -> MediaCodec
 * -> Surface is the chain this proves end to end (plan's AD-P2.2:
 * risk-first vertical slice). SurfaceView, not TextureView, per F5.5 --
 * this requires Hybrid Composition, which is Flutter's default for
 * `AndroidView` since 3.0, so no special Dart-side opt-in is needed.
 *
 * Registered via [io.flutter.plugin.platform.PlatformViewRegistry] in
 * MainActivity under [VIEW_TYPE_ID]. [onPhase] forwards playback-phase
 * transitions to `AiroStreamingEnginePlugin.notifyPhase` (Task 5's state
 * stream) -- stableIds match [AiroPlaybackEnginePhase] in `platform_player`
 * so the Dart side never forks a parallel phase vocabulary.
 */
class AiroStreamingSurfaceViewFactory(private val onPhase: (String) -> Unit) :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val VIEW_TYPE_ID = "com.airo.player/streaming_surface"
        private const val TAG = "AiroStreamingSurface"

        // Apple's public bipbop HLS test asset -- stable, no auth, no
        // provider dependency. Replaced by a real channel source once Wave
        // B's custom DataSource exists; this factory only proves the
        // rendering path.
        private const val TEST_STREAM_URL =
            "https://devstreaming-cdn.apple.com/videos/streaming/examples/" +
                "bipbop_16x9/bipbop_16x9_variant.m3u8"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return AiroStreamingPlatformView(context, onPhase)
    }

    private class AiroStreamingPlatformView(
        context: Context,
        private val onPhase: (String) -> Unit,
    ) : PlatformView {
        private val surfaceView = SurfaceView(context)

        // Tracked locally rather than read from `player` inside the
        // listener: addListener() below can synchronously fire an initial
        // callback before the `player` property itself has finished being
        // assigned (its initializer is still running `.apply {}` at that
        // point), which crashed with a NullPointerException on a real
        // device -- confirmed by device testing, not a hypothetical.
        private var lastPlaybackState = Player.STATE_IDLE
        private var lastPlayWhenReady = false
        private val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                Log.d(TAG, "onPlaybackStateChanged: ${stateName(playbackState)}")
                lastPlaybackState = playbackState
                onPhase(mapPhase(lastPlaybackState, lastPlayWhenReady))
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                Log.d(TAG, "onPlayWhenReadyChanged: $playWhenReady (reason=$reason)")
                lastPlayWhenReady = playWhenReady
                onPhase(mapPhase(lastPlaybackState, lastPlayWhenReady))
            }

            override fun onPlayerError(error: PlaybackException) {
                Log.e(TAG, "onPlayerError: ${error.errorCodeName} - ${error.message}", error)
                onPhase("failed")
            }

            override fun onMediaItemTransition(mediaItem: MediaItem?, reason: Int) {
                Log.d(TAG, "onMediaItemTransition: ${mediaItem?.localConfiguration?.uri} (reason=$reason)")
            }

            override fun onRenderedFirstFrame() {
                Log.d(TAG, "onRenderedFirstFrame")
            }
        }

        // Task 1 (splice plan): HLS segments are boundary-aligned on
        // keyframes by spec, so onLoadCompleted's mediaEndTimeMs for the
        // video track *is* a splice-safe point, detected for free.
        // C.TIME_UNSET is filtered here (device-specific sentinel
        // handling) so the pure tracker only ever sees valid timestamps.
        private val boundaryTracker = AiroSegmentBoundaryTracker()
        private val analyticsListener = object : AnalyticsListener {
            override fun onLoadCompleted(
                eventTime: AnalyticsListener.EventTime,
                loadEventInfo: LoadEventInfo,
                mediaLoadData: MediaLoadData,
            ) {
                if (mediaLoadData.trackType != C.TRACK_TYPE_VIDEO) return
                val endMs = mediaLoadData.mediaEndTimeMs
                if (endMs == C.TIME_UNSET) return
                boundaryTracker.onSegmentLoaded(endMs)
                Log.d(TAG, "segment boundary tracked: mediaEndTimeMs=$endMs")
            }
        }
        private val player: ExoPlayer

        init {
            Log.d(TAG, "creating ExoPlayer, dataSourceFactory=${AiroStreamingEngine.dataSourceFactory}")
            player = ExoPlayer.Builder(context)
                .setMediaSourceFactory(DefaultMediaSourceFactory(AiroStreamingEngine.dataSourceFactory))
                .build()
            Log.d(TAG, "ExoPlayer built, attaching surface + listener")
            player.setVideoSurfaceView(surfaceView)
            player.addListener(listener)
            player.addAnalyticsListener(analyticsListener)
            Log.d(TAG, "setting MediaItem: $TEST_STREAM_URL")
            player.setMediaItem(MediaItem.fromUri(TEST_STREAM_URL))
            Log.d(TAG, "calling prepare()")
            player.prepare()
            player.playWhenReady = true
            Log.d(TAG, "prepare() returned, playWhenReady=true set, current state=${stateName(player.playbackState)}")
            AiroStreamingEngine.currentPlayer = player
            AiroStreamingEngine.currentSegmentBoundaryTracker = boundaryTracker
        }

        private fun stateName(state: Int): String = when (state) {
            Player.STATE_IDLE -> "IDLE"
            Player.STATE_BUFFERING -> "BUFFERING"
            Player.STATE_READY -> "READY"
            Player.STATE_ENDED -> "ENDED"
            else -> "UNKNOWN($state)"
        }

        private fun mapPhase(playbackState: Int, playWhenReady: Boolean): String {
            return when (playbackState) {
                Player.STATE_IDLE -> "idle"
                Player.STATE_BUFFERING -> "buffering"
                Player.STATE_READY -> if (playWhenReady) "playing" else "paused"
                Player.STATE_ENDED -> "ended"
                else -> "unavailable"
            }
        }

        override fun getView(): View = surfaceView

        override fun dispose() {
            if (AiroStreamingEngine.currentPlayer === player) {
                AiroStreamingEngine.currentPlayer = null
                AiroStreamingEngine.currentSegmentBoundaryTracker = null
            }
            player.removeListener(listener)
            player.removeAnalyticsListener(analyticsListener)
            player.release()
        }
    }
}
