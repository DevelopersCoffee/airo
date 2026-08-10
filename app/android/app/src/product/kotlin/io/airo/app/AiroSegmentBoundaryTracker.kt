package io.airo.app

/**
 * Task 1 of tasks/tv-zero-copy-cast-splice-plan.md. Pure tracking logic
 * for "how far until the next HLS segment boundary" -- HLS segments are
 * boundary-aligned on keyframes by spec, so detecting the boundary *is*
 * detecting a splice-safe point, for free (see the plan's investigation
 * findings). Zero Media3 dependency, so it lives in shared
 * `src/product/kotlin` and is JVM-testable, same reasoning as
 * [AiroSpliceDecision] (AD-P2B.4).
 *
 * The actual boundary timestamps come from Media3's `AnalyticsListener`
 * (`onLoadCompleted`'s `MediaLoadData.mediaEndTimeMs` for the video
 * track) -- that wiring lives in `AiroStreamingSurfaceViewFactory`
 * (`src/tv/kotlin`), which is the only part of this that actually needs
 * a device to verify (real HLS loading timing, not something a JVM fake
 * can prove).
 */
class AiroSegmentBoundaryTracker {
    private var latestSegmentEndMs: Long? = null

    /** Ignores out-of-order/duplicate loads -- the boundary only ever
     * moves forward, matching how a real player loads segments in
     * increasing playback order except for rare reordered late loads. */
    fun onSegmentLoaded(mediaEndTimeMs: Long) {
        val current = latestSegmentEndMs
        if (current == null || mediaEndTimeMs > current) {
            latestSegmentEndMs = mediaEndTimeMs
        }
    }

    /** Null when no boundary is known yet, or the most recently tracked
     * boundary has already been played past (stale -- a fresher load
     * hasn't arrived yet, so guessing would be wrong). */
    fun msUntilNextBoundary(currentPositionMs: Long): Long? {
        val endMs = latestSegmentEndMs ?: return null
        val remaining = endMs - currentPositionMs
        return if (remaining >= 0) remaining else null
    }

    fun reset() {
        latestSegmentEndMs = null
    }
}
