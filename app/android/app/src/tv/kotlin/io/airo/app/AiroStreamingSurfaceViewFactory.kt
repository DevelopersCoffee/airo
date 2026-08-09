package io.airo.app

import android.content.Context
import android.view.SurfaceView
import android.view.View
import androidx.media3.common.MediaItem
import androidx.media3.exoplayer.ExoPlayer
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Wave A proof-of-concept receiver surface (SPEC.md AD-1/AD-5, Phase 2).
 *
 * Hosts a bare [SurfaceView] driven by a stock Media3 [ExoPlayer] playing
 * one hardcoded public HLS test stream -- proves the whole chain (Flutter
 * PlatformView -> Kotlin -> MediaCodec -> Surface) renders a frame before
 * any custom DataSource/DNS/pooling sophistication is built on top (plan's
 * AD-P2.2: risk-first vertical slice). SurfaceView, not TextureView, per
 * F5.5 -- this requires Hybrid Composition, which is Flutter's default for
 * `AndroidView` since 3.0, so no special Dart-side opt-in is needed.
 *
 * Registered via [io.flutter.plugin.platform.PlatformViewRegistry] in
 * MainActivity under [VIEW_TYPE_ID].
 */
class AiroStreamingSurfaceViewFactory :
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
        return AiroStreamingPlatformView(context)
    }

    private class AiroStreamingPlatformView(context: Context) : PlatformView {
        private val surfaceView = SurfaceView(context)
        private val player = ExoPlayer.Builder(context).build().apply {
            setVideoSurfaceView(surfaceView)
            setMediaItem(MediaItem.fromUri(TEST_STREAM_URL))
            prepare()
            playWhenReady = true
        }

        override fun getView(): View = surfaceView

        override fun dispose() {
            player.release()
        }
    }
}
