package io.airo.app

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Test

class AiroSpliceDecisionTest {
    private val pool = Executors.newCachedThreadPool()

    @After
    fun shutdownPool() {
        pool.shutdownNow()
    }

    private class FakeFinder(
        private val result: Boolean,
        private val releaseLatch: CountDownLatch? = null,
    ) : AiroSplicePointFinder {
        override fun findNextSplicePoint(): Boolean {
            releaseLatch?.await(5, TimeUnit.SECONDS)
            return result
        }
    }

    @Test
    fun `no finder falls back to mute-cut without attempting a search`() {
        val mode = AiroSpliceDecision.decide(finder = null, deadlineMs = 3000, executor = pool)

        assertEquals(AiroSpliceMode.MUTE_CUT_FALLBACK, mode)
    }

    @Test
    fun `a finder that reports a splice point within the deadline splices`() {
        val finder = FakeFinder(result = true)

        val mode = AiroSpliceDecision.decide(finder, deadlineMs = 3000, executor = pool)

        assertEquals(AiroSpliceMode.SPLICE, mode)
    }

    @Test
    fun `a finder that reports no splice point falls back to mute-cut`() {
        val finder = FakeFinder(result = false)

        val mode = AiroSpliceDecision.decide(finder, deadlineMs = 3000, executor = pool)

        assertEquals(AiroSpliceMode.MUTE_CUT_FALLBACK, mode)
    }

    @Test
    fun `a finder that exceeds the deadline falls back to mute-cut rather than hanging`() {
        val neverReleases = CountDownLatch(1)
        val hangingFinder = FakeFinder(result = true, releaseLatch = neverReleases)

        try {
            val mode = AiroSpliceDecision.decide(hangingFinder, deadlineMs = 100, executor = pool)

            assertEquals(AiroSpliceMode.MUTE_CUT_FALLBACK, mode)
        } finally {
            neverReleases.countDown()
        }
    }

    @Test
    fun `a finder that throws falls back to mute-cut rather than propagating`() {
        val throwingFinder = object : AiroSplicePointFinder {
            override fun findNextSplicePoint(): Boolean = throw RuntimeException("parser blew up")
        }

        val mode = AiroSpliceDecision.decide(throwingFinder, deadlineMs = 3000, executor = pool)

        assertEquals(AiroSpliceMode.MUTE_CUT_FALLBACK, mode)
    }
}
