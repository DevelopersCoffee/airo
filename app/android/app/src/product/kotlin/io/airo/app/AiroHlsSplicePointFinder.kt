package io.airo.app

/**
 * Task 2 of tasks/tv-zero-copy-cast-splice-plan.md. Polls
 * [msUntilNextBoundary] until Task 1's tracked HLS segment boundary is
 * imminent, then sleeps the remaining gap so [AiroSpliceDecision] (which
 * runs this on its own executor thread, bounded by its own deadline)
 * hands back control right around the boundary.
 *
 * [msUntilNextBoundary] is injected rather than read from
 * `AiroStreamingEngine` directly -- this keeps the polling logic itself
 * Media3-free and JVM-testable (AD-P2B.4), and matters for real
 * correctness too: the real supplier
 * (`AiroStreamingEngine::msUntilNextHlsBoundary`) must never touch the
 * live `ExoPlayer` instance from this background thread, since Media3
 * requires all player access to happen on its own application thread --
 * see `AiroStreamingSurfaceViewFactory`'s position-poll cache for how
 * the real supplier stays thread-safe.
 */
class AiroHlsSplicePointFinder(
    private val msUntilNextBoundary: () -> Long?,
    private val pollIntervalMs: Long = 100,
    private val imminentThresholdMs: Long = 250,
) : AiroSplicePointFinder {
    override fun findNextSplicePoint(): Boolean {
        while (true) {
            val remaining = msUntilNextBoundary()
            if (remaining == null) {
                Thread.sleep(pollIntervalMs)
                continue
            }
            if (remaining <= imminentThresholdMs) {
                if (remaining > 0) Thread.sleep(remaining)
                return true
            }
            Thread.sleep(minOf(pollIntervalMs, remaining))
        }
    }
}
