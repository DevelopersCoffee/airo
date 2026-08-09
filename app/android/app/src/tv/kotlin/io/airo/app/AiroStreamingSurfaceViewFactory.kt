package io.airo.app

import android.content.Context
import android.view.SurfaceView
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
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
        private val listener = object : Player.Listener {
            override fun onPlaybackStateChanged(playbackState: Int) {
                onPhase(mapPhase(playbackState, player.playWhenReady))
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                onPhase(mapPhase(player.playbackState, playWhenReady))
            }

            override fun onPlayerError(error: PlaybackException) {
                onPhase("failed")
            }
        }
        private val player: ExoPlayer = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(AiroStreamingEngine.dataSourceFactory))
            .build()
            .apply {
            setVideoSurfaceView(surfaceView)
            addListener(listener)
            setMediaItem(MediaItem.fromUri(TEST_STREAM_URL))
            prepare()
            playWhenReady = true
        }

        init {
            AiroStreamingEngine.currentPlayer = player
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
            }
            player.removeListener(listener)
            player.release()
        }
    }
}
