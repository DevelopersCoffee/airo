package io.airo.app

import java.io.File
import mockwebserver3.MockResponse
import mockwebserver3.MockWebServer
import okhttp3.OkHttpClient
import okio.Buffer
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroTsSplicePointFinderTest {
    private val realEncoderBytes = File(
        "src/test/resources/fixtures/mpeg_ts/libx264_sample.ts",
    ).readBytes()

    @Test
    fun `finds a splice point against real encoder bytes served locally`() {
        val server = MockWebServer()
        server.start()
        try {
            server.enqueue(MockResponse.Builder().body(Buffer().write(realEncoderBytes)).build())
            val url = server.url("/stream.ts").toString()
            val finder = AiroTsSplicePointFinder(OkHttpClient(), url)

            assertTrue(finder.findNextSplicePoint())
        } finally {
            server.close()
        }
    }

    @Test
    fun `a stream with no IDR within the probe budget reports no splice point`() {
        val server = MockWebServer()
        server.start()
        try {
            // Only PAT+PMT, no video payload at all.
            val patAndPmtOnly = realEncoderBytes.copyOfRange(0, 2 * 188)
            server.enqueue(MockResponse.Builder().body(Buffer().write(patAndPmtOnly)).build())
            val url = server.url("/stream.ts").toString()
            val finder = AiroTsSplicePointFinder(OkHttpClient(), url)

            assertFalse(finder.findNextSplicePoint())
        } finally {
            server.close()
        }
    }

    @Test
    fun `an unreachable host reports no splice point without throwing`() {
        val finder = AiroTsSplicePointFinder(OkHttpClient(), "http://127.0.0.1:1/unreachable")

        assertFalse(finder.findNextSplicePoint())
    }

    @Test
    fun `a non-2xx response reports no splice point`() {
        val server = MockWebServer()
        server.start()
        try {
            server.enqueue(MockResponse(code = 404))
            val url = server.url("/missing.ts").toString()
            val finder = AiroTsSplicePointFinder(OkHttpClient(), url)

            assertFalse(finder.findNextSplicePoint())
        } finally {
            server.close()
        }
    }
}
