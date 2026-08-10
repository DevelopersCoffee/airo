package io.airo.app

import org.junit.Assert.assertTrue
import org.junit.Test

class AiroHlsSplicePointFinderTest {
    @Test
    fun `returns true immediately when a boundary is already at hand`() {
        val finder = AiroHlsSplicePointFinder(
            msUntilNextBoundary = { 0L },
            pollIntervalMs = 5,
            imminentThresholdMs = 50,
        )

        assertTrue(finder.findNextSplicePoint())
    }

    @Test
    fun `polls until a reported boundary becomes imminent`() {
        val values = ArrayDeque(listOf(500L, 300L, 40L))
        val finder = AiroHlsSplicePointFinder(
            msUntilNextBoundary = { values.removeFirstOrNull() ?: 40L },
            pollIntervalMs = 5,
            imminentThresholdMs = 50,
        )

        assertTrue(finder.findNextSplicePoint())
    }

    @Test
    fun `keeps polling through unknown boundaries until one appears`() {
        val values = ArrayDeque<Long?>(listOf(null, null, 10L))
        val finder = AiroHlsSplicePointFinder(
            msUntilNextBoundary = { values.removeFirstOrNull() ?: 10L },
            pollIntervalMs = 5,
            imminentThresholdMs = 50,
        )

        assertTrue(finder.findNextSplicePoint())
    }
}
