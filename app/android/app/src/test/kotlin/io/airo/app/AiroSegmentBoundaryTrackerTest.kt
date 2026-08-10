package io.airo.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AiroSegmentBoundaryTrackerTest {
    @Test
    fun `no segment loaded yet reports unknown boundary`() {
        val tracker = AiroSegmentBoundaryTracker()

        assertNull(tracker.msUntilNextBoundary(currentPositionMs = 0))
    }

    @Test
    fun `reports remaining time to the most recently loaded segment end`() {
        val tracker = AiroSegmentBoundaryTracker()

        tracker.onSegmentLoaded(mediaEndTimeMs = 10_000)

        assertEquals(7_000L, tracker.msUntilNextBoundary(currentPositionMs = 3_000))
    }

    @Test
    fun `a boundary already behind current position is stale and reports unknown`() {
        val tracker = AiroSegmentBoundaryTracker()

        tracker.onSegmentLoaded(mediaEndTimeMs = 10_000)

        assertNull(tracker.msUntilNextBoundary(currentPositionMs = 11_000))
    }

    @Test
    fun `out-of-order or duplicate loads never move the boundary backwards`() {
        val tracker = AiroSegmentBoundaryTracker()

        tracker.onSegmentLoaded(mediaEndTimeMs = 10_000)
        tracker.onSegmentLoaded(mediaEndTimeMs = 6_000)

        assertEquals(7_000L, tracker.msUntilNextBoundary(currentPositionMs = 3_000))
    }

    @Test
    fun `reset clears tracked state back to unknown`() {
        val tracker = AiroSegmentBoundaryTracker()
        tracker.onSegmentLoaded(mediaEndTimeMs = 10_000)

        tracker.reset()

        assertNull(tracker.msUntilNextBoundary(currentPositionMs = 3_000))
    }
}
