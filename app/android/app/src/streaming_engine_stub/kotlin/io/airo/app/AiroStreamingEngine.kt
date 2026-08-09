package io.airo.app

/**
 * Stub replacement for the real (OkHttp-backed) streaming engine wiring,
 * compiled in on every non-tv variant (Media3/OkHttp are `isTvVariant`-
 * gated -- see `app/android/app/build.gradle.kts`). Same shape as
 * `AiroStreamingSurfaceViewFactory`'s real/stub split: identical public
 * API so `AiroStreamingEnginePlugin`'s `preWarm` handler always resolves
 * regardless of variant. Phone/Mind/Coins never call `preWarm` (their
 * Dart side has no reason to), so this is never observably a no-op to a
 * user.
 */
object AiroStreamingEngine {
    fun preWarm(hosts: List<String>) {}
}
