package io.airo.app

import android.content.Context
import android.view.View
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/**
 * Stub replacement for the real (Media3-backed) streaming surface factory,
 * compiled in on every non-tv variant (see `app/android/app/build.gradle.kts`
 * -- Media3 is `isTvVariant`-gated, so a non-tv build must never compile a
 * file that imports `androidx.media3.*`).
 *
 * Same shape as `LiteRtLmPlugin`'s available/unavailable split: identical
 * public API (same class name, same [VIEW_TYPE_ID]) so MainActivity's
 * registration call always resolves regardless of variant. The Dart side
 * never requests this view type on phone/Mind/Coins builds, so the plain
 * empty [View] this returns is never actually shown to a user.
 */
class AiroStreamingSurfaceViewFactory :
    PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    companion object {
        const val VIEW_TYPE_ID = "com.airo.player/streaming_surface"
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        return object : PlatformView {
            private val emptyView = View(context)

            override fun getView(): View = emptyView

            override fun dispose() {}
        }
    }
}
