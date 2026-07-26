package io.airo.app

import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MediaAnalysisJobTest {
    @Test
    fun cancellingQueuedJobCompletesExactlyOnceWithoutRunningAnalysis() {
        val executor = Executors.newSingleThreadExecutor()
        val blockerStarted = CountDownLatch(1)
        val releaseBlocker = CountDownLatch(1)
        executor.execute {
            blockerStarted.countDown()
            releaseBlocker.await()
        }
        assertTrue(blockerStarted.await(2, TimeUnit.SECONDS))

        var analysisRuns = 0
        val results = mutableListOf<String>()
        val job = MediaAnalysisJob(
            analysis = {
                analysisRuns += 1
                "complete"
            },
            cancelledResult = { "cancelled" },
            failedResult = { "inspection-failed" },
            complete = results::add,
        )

        job.enqueueOn(executor)
        job.cancel()
        releaseBlocker.countDown()
        executor.shutdown()
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))

        assertEquals(0, analysisRuns)
        assertEquals(listOf("cancelled"), results)
    }

    @Test
    fun cancellingRunningJobReturnsCancelledOnlyOnce() {
        val executor = Executors.newSingleThreadExecutor()
        val analysisStarted = CountDownLatch(1)
        val analysisInterrupted = CountDownLatch(1)
        val results = mutableListOf<String>()
        val job = MediaAnalysisJob(
            analysis = {
                analysisStarted.countDown()
                try {
                    CountDownLatch(1).await()
                    "complete"
                } catch (_: InterruptedException) {
                    analysisInterrupted.countDown()
                    "cancelled-from-analysis"
                }
            },
            cancelledResult = { "cancelled" },
            failedResult = { "inspection-failed" },
            complete = results::add,
        )

        job.enqueueOn(executor)
        assertTrue(analysisStarted.await(2, TimeUnit.SECONDS))
        job.cancel()
        assertTrue(analysisInterrupted.await(2, TimeUnit.SECONDS))
        executor.shutdown()
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))

        assertEquals(listOf("cancelled"), results)
    }

    @Test
    fun unexpectedAnalysisFailureCompletesAndDoesNotLeakTheJob() {
        val executor = Executors.newSingleThreadExecutor()
        val results = mutableListOf<String>()
        val job = MediaAnalysisJob(
            analysis = { error("unexpected native failure") },
            cancelledResult = { "cancelled" },
            failedResult = { "inspection-failed" },
            complete = results::add,
        )

        job.enqueueOn(executor)
        executor.shutdown()
        assertTrue(executor.awaitTermination(2, TimeUnit.SECONDS))

        assertEquals(listOf("inspection-failed"), results)
    }
}
