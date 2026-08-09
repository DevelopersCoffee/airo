package io.airo.app

import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import okhttp3.OkHttpClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroShadowFetchTest {
    @Test
    fun `probe measures throughput from a real local server`() {
        val server = MockWebServer()
        server.start()
        try {
            server.enqueue(MockResponse(body = "x".repeat(64 * 1024)))
            val url = server.url("/").toString()
            val limiter = AiroShadowFetchLimiter()

            val result = AiroShadowFetch.probe(OkHttpClient(), url, limiter, maxBytes = 64 * 1024)

            assertTrue("expected a successful probe", result is AiroShadowFetchResult.Measured)
            val measured = result as AiroShadowFetchResult.Measured
            assertTrue("throughput should be positive", measured.throughputKbps > 0)
        } finally {
            server.close()
        }
    }

    @Test
    fun `a probe against an unreachable host fails without throwing`() {
        val limiter = AiroShadowFetchLimiter()
        val result = AiroShadowFetch.probe(
            OkHttpClient(),
            "http://127.0.0.1:1/unreachable",
            limiter,
            maxBytes = 1024,
        )

        assertTrue(result is AiroShadowFetchResult.Failed)
    }

    @Test
    fun `the limiter allows only one concurrent shadow fetch`() {
        val limiter = AiroShadowFetchLimiter()

        assertTrue(limiter.tryAcquire())
        assertFalse("a second concurrent acquire should be rejected", limiter.tryAcquire())
        limiter.release()
        assertTrue("release should free the slot for a new acquire", limiter.tryAcquire())
        limiter.release()
    }

    @Test
    fun `a probe rejected by the limiter returns Busy without hitting the network`() {
        val limiter = AiroShadowFetchLimiter()
        val client = OkHttpClient()

        val holderReady = CountDownLatch(1)
        val releaseHolder = CountDownLatch(1)
        val holderThread = Thread {
            limiter.tryAcquire()
            holderReady.countDown()
            releaseHolder.await()
            limiter.release()
        }
        holderThread.start()
        assertTrue(holderReady.await(2, TimeUnit.SECONDS))

        // Deliberately unreachable -- if probe() ever fell through to the
        // network despite the limiter rejecting it, this would surface as
        // a Failed result instead of Busy, catching the bug.
        val result = AiroShadowFetch.probe(client, "http://127.0.0.1:1/unreachable", limiter, maxBytes = 1024)
        assertEquals(AiroShadowFetchResult.Busy, result)

        releaseHolder.countDown()
        holderThread.join(2000)
    }
}
