package io.airo.app

import java.util.concurrent.ExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Splice-on-keyframe foundation (F4.4.5/F4.4.6, follow-up to Wave C
 * Task 1's `switchSource` basic swap). Pure decision logic + the outcome
 * shape -- no Media3/ExoPlayer dependency, so it lives in the shared
 * `src/product/kotlin` and is fully JVM-testable, same reasoning as
 * `AiroResolverCache` (Wave B, AD-P2B.4).
 *
 * Not yet wired into the live `switchSource` method-channel path: there
 * is no real [AiroSplicePointFinder] implementation until the HLS
 * (Task 1/2) or TS (Task 4/5) detection work lands. Wiring this in before
 * then would make every switchSource call take the fallback path
 * unconditionally, changing already-device-verified behavior for no
 * benefit -- see tasks/tv-zero-copy-cast-splice-plan.md's Task 0 scope.
 */
enum class AiroSpliceMode { SPLICE, MUTE_CUT_FALLBACK }

/**
 * Task 2's richer outcome for `AiroStreamingEngine.switchSource` --
 * distinguishes a clean splice from a mute-cut fallback from an outright
 * failure (no live player), rather than collapsing all three into one
 * boolean the way `switchSource`'s v1 basic swap did (AD-Splice.3). The
 * method-channel boundary carries this across as a status string --
 * `AiroStreamingEnginePlugin` maps each value to `"spliced"` /
 * `"fellBackToMuteCut"` / `"failed"`, and
 * `platform_streaming_engine`'s `AiroSwitchSourceOutcome` sealed class
 * mirrors it on the Dart side (splice-plan final checkpoint).
 */
enum class AiroSpliceOutcome { SPLICED, FELL_BACK_TO_MUTE_CUT, FAILED }

/**
 * Reports whether a splice-safe point (PAT/PMT+IDR for TS, next segment
 * boundary for HLS) was found. Implementations do their own internal
 * work however long it takes -- [AiroSpliceDecision] is what enforces the
 * deadline, so a finder is never trusted to self-bound.
 */
interface AiroSplicePointFinder {
    fun findNextSplicePoint(): Boolean
}

/**
 * Structurally guarantees F4.4.6's bounded, safe failure mode: a splice
 * attempt always resolves to [AiroSpliceMode.SPLICE] or
 * [AiroSpliceMode.MUTE_CUT_FALLBACK] within [deadlineMs], regardless of
 * whether [finder] is slow, hangs, or throws. Never propagates an
 * exception and never blocks past the deadline.
 */
object AiroSpliceDecision {
    fun decide(
        finder: AiroSplicePointFinder?,
        deadlineMs: Long,
        executor: ExecutorService,
    ): AiroSpliceMode {
        if (finder == null) return AiroSpliceMode.MUTE_CUT_FALLBACK

        val future = executor.submit<Boolean> { finder.findNextSplicePoint() }
        return try {
            if (future.get(deadlineMs, TimeUnit.MILLISECONDS)) {
                AiroSpliceMode.SPLICE
            } else {
                AiroSpliceMode.MUTE_CUT_FALLBACK
            }
        } catch (_: TimeoutException) {
            future.cancel(true)
            AiroSpliceMode.MUTE_CUT_FALLBACK
        } catch (_: Exception) {
            AiroSpliceMode.MUTE_CUT_FALLBACK
        }
    }
}
