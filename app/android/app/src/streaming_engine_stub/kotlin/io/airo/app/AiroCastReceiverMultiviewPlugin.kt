package io.airo.app

import io.flutter.plugin.common.BinaryMessenger

/**
 * Stub replacement for the real (Cast Connect-backed) MultiView receiver
 * bridge, compiled in on every non-tv variant (see
 * `app/android/app/build.gradle.kts` -- `play-services-cast-tv` is
 * `isTvVariant`-gated, so a non-tv build must never compile a file that
 * imports `com.google.android.gms.cast.tv.*`).
 *
 * Same shape as `AiroStreamingSurfaceViewFactory`'s available/unavailable
 * split: identical public API (same class name, same [register] signature)
 * so MainActivity's registration call always resolves regardless of
 * variant. The Dart side only reaches for this channel on the TV build, so
 * this stub's method channel simply never receives a call on phone/Mind/Coins.
 */
class AiroCastReceiverMultiviewPlugin {
    fun register(messenger: BinaryMessenger) {}
}
