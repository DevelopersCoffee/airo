package io.airo.app

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class AiroTsSpliceParserTest {
    private fun tsPacket(pid: Int, payloadUnitStart: Boolean, payload: ByteArray): ByteArray {
        val packet = ByteArray(188)
        packet[0] = 0x47
        packet[1] = ((if (payloadUnitStart) 0x40 else 0x00) or ((pid shr 8) and 0x1F)).toByte()
        packet[2] = (pid and 0xFF).toByte()
        packet[3] = 0x10 // adaptation_field_control=01 (payload only), cc=0
        val payloadStart = 4
        val copyLength = minOf(payload.size, 184)
        System.arraycopy(payload, 0, packet, payloadStart, copyLength)
        for (i in payloadStart + copyLength until 188) {
            packet[i] = 0xFF.toByte()
        }
        return packet
    }

    private val patPayload = byteArrayOf(
        0x00, 0x00, 0xB0.toByte(), 0x0D, 0x00, 0x01, 0xC1.toByte(), 0x00, 0x00,
        0x00, 0x01, 0xE0.toByte(), 0x20, 0x00, 0x00, 0x00, 0x00,
    )

    private val pmtPayload = byteArrayOf(
        0x00, 0x02, 0xB0.toByte(), 0x12, 0x00, 0x01, 0xC1.toByte(), 0x00, 0x00,
        0xE0.toByte(), 0x21, 0xF0.toByte(), 0x00, 0x1B, 0xE0.toByte(), 0x21,
        0xF0.toByte(), 0x00, 0x00, 0x00, 0x00, 0x00,
    )

    // PES header (video, no PTS/DTS) + Annex-B start code + IDR NAL header.
    private val videoPayloadWithIdr = byteArrayOf(
        0x00, 0x00, 0x01, 0xE0.toByte(), 0x00, 0x00, 0x80.toByte(), 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x65, 0x88.toByte(), 0x84.toByte(), 0x00,
    )

    @Test
    fun `finds the IDR packet index after walking PAT then PMT then video PID`() {
        val parser = AiroTsSpliceParser()
        val stream = tsPacket(0x0000, true, patPayload) +
            tsPacket(0x0020, true, pmtPayload) +
            tsPacket(0x0021, true, videoPayloadWithIdr)

        assertEquals(2, parser.feed(stream))
    }

    @Test
    fun `feeding chunks split mid-packet still resolves correctly`() {
        val parser = AiroTsSpliceParser()
        val stream = tsPacket(0x0000, true, patPayload) +
            tsPacket(0x0020, true, pmtPayload) +
            tsPacket(0x0021, true, videoPayloadWithIdr)

        var result: Int? = null
        var offset = 0
        val chunkSize = 57 // deliberately not 188-aligned
        while (offset < stream.size) {
            val end = minOf(offset + chunkSize, stream.size)
            val found = parser.feed(stream.copyOfRange(offset, end))
            if (found != null) result = found
            offset = end
        }

        assertEquals(2, result)
    }

    @Test
    fun `garbage input never throws and never resolves`() {
        val parser = AiroTsSpliceParser()
        val garbage = ByteArray(2000) { (it * 91 + 7).toByte() }

        assertNull(parser.feed(garbage))
    }

    @Test
    fun `a program with no video stream never resolves`() {
        val parser = AiroTsSpliceParser()
        val audioOnlyPmt = pmtPayload.copyOf()
        audioOnlyPmt[13] = 0x0F // AAC audio, not video
        val stream = tsPacket(0x0000, true, patPayload) + tsPacket(0x0020, true, audioOnlyPmt)

        assertNull(parser.feed(stream))
    }

    @Test
    fun `real encoder bytes resolve a genuine splice point`() {
        // Locally encoded via ffmpeg/libx264 -- see the fixture's own
        // note in tasks/tv-zero-copy-cast-splice-plan.md for why: the
        // originally downloaded real broadcast capture
        // (samples.ffmpeg.org/ts/01c56b0dc1.ts) turned out to never
        // emit a spec-compliant NAL type 5 for its keyframes at all
        // (confirmed by scanning the entire 11MB file), a genuine
        // real-world encoder quirk the plan's own risk table
        // anticipated -- not a bug in this parser. libx264 is a real,
        // widely-deployed H.264 encoder and does emit standard IDR
        // NALs, so this fixture still proves the parser against actual
        // encoder output, just not hand-typed synthetic bytes.
        val fixture = File(
            "src/test/resources/fixtures/mpeg_ts/libx264_sample.ts",
        )
        val bytes = fixture.readBytes()
        val parser = AiroTsSpliceParser()

        var result: Int? = null
        var offset = 0
        val chunkSize = 4096
        while (offset < bytes.size && result == null) {
            val end = minOf(offset + chunkSize, bytes.size)
            result = parser.feed(bytes.copyOfRange(offset, end))
            offset = end
        }

        assertNotNull(
            "expected a real PAT->PMT->video PID->IDR chain to resolve against real encoder bytes",
            result,
        )
    }
}
