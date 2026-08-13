package io.airo.app

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroH264IdrDetectorTest {
    @Test
    fun `detects an IDR NAL start code within a single feed`() {
        val detector = AiroH264IdrDetector()
        val bytes = byteArrayOf(0x00, 0x00, 0x00, 0x01, 0x65, 0x88.toByte())

        assertTrue(detector.feed(bytes))
    }

    @Test
    fun `ignores non-IDR NAL types`() {
        val detector = AiroH264IdrDetector()
        // NAL type 1 (non-IDR coded slice)
        val bytes = byteArrayOf(0x00, 0x00, 0x00, 0x01, 0x61, 0x88.toByte())

        assertFalse(detector.feed(bytes))
    }

    @Test
    fun `detects a start code split across two feed calls`() {
        val detector = AiroH264IdrDetector()
        assertFalse(detector.feed(byteArrayOf(0x00, 0x00, 0x00)))
        assertTrue(detector.feed(byteArrayOf(0x01, 0x65, 0x88.toByte())))
    }

    @Test
    fun `random data never throws and never false-positives`() {
        val detector = AiroH264IdrDetector()
        val random = ByteArray(1000) { (it * 37 + 11).toByte() }

        assertFalse(detector.feed(random))
    }

    @Test
    fun `reset clears carried-over tail state`() {
        val detector = AiroH264IdrDetector()
        detector.feed(byteArrayOf(0x00, 0x00, 0x00))
        detector.reset()

        // Without the reset, feeding "01 65" alone would complete the
        // split start code from above and false-positive.
        assertFalse(detector.feed(byteArrayOf(0x01, 0x65)))
    }
}
