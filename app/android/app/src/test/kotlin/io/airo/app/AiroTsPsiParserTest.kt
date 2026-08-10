package io.airo.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AiroTsPsiParserTest {
    // PAT: program_number=0x0001 -> PMT PID=0x0020. Pointer field 0x00.
    private val patPayload = byteArrayOf(
        0x00, // pointer_field
        0x00, // table_id (PAT)
        0xB0.toByte(), 0x0D, // section_length=13
        0x00, 0x01, // transport_stream_id
        0xC1.toByte(), // version/current_next
        0x00, // section_number
        0x00, // last_section_number
        0x00, 0x01, // program_number=1
        0xE0.toByte(), 0x20, // reserved + PMT_PID=0x0020
        0x00, 0x00, 0x00, 0x00, // CRC32 (unchecked)
    )

    // PMT for the program above: video PID=0x0021, stream_type=0x1B (AVC).
    private val pmtPayload = byteArrayOf(
        0x00, // pointer_field
        0x02, // table_id (PMT)
        0xB0.toByte(), 0x12, // section_length=18
        0x00, 0x01, // program_number
        0xC1.toByte(), // version/current_next
        0x00, // section_number
        0x00, // last_section_number
        0xE0.toByte(), 0x21, // reserved + PCR_PID
        0xF0.toByte(), 0x00, // reserved + program_info_length=0
        0x1B, // stream_type = H.264/AVC video
        0xE0.toByte(), 0x21, // reserved + elementary_PID=0x0021
        0xF0.toByte(), 0x00, // reserved + ES_info_length=0
        0x00, 0x00, 0x00, 0x00, // CRC32 (unchecked)
    )

    @Test
    fun `finds the PMT pid from a PAT skipping program 0`() {
        assertEquals(0x0020, AiroTsPsiParser.findPmtPid(patPayload))
    }

    @Test
    fun `PAT with only a network PID entry (program 0) has no PMT`() {
        val networkOnly = byteArrayOf(
            0x00,
            0x00,
            0xB0.toByte(), 0x0D,
            0x00, 0x01,
            0xC1.toByte(),
            0x00,
            0x00,
            0x00, 0x00, // program_number=0 (network PID entry)
            0xE0.toByte(), 0x10,
            0x00, 0x00, 0x00, 0x00,
        )
        assertNull(AiroTsPsiParser.findPmtPid(networkOnly))
    }

    @Test
    fun `finds the h264 video pid from a PMT`() {
        assertEquals(0x0021, AiroTsPsiParser.findVideoPid(pmtPayload))
    }

    @Test
    fun `a PMT with no video stream reports no video pid`() {
        val audioOnly = pmtPayload.copyOf()
        audioOnly[13] = 0x0F // stream_type -> AAC audio, not video
        assertNull(AiroTsPsiParser.findVideoPid(audioOnly))
    }

    @Test
    fun `truncated or empty payloads never throw`() {
        assertNull(AiroTsPsiParser.findPmtPid(ByteArray(0)))
        assertNull(AiroTsPsiParser.findPmtPid(byteArrayOf(0x00, 0x00, 0x01)))
        assertNull(AiroTsPsiParser.findVideoPid(ByteArray(0)))
        assertNull(AiroTsPsiParser.findVideoPid(byteArrayOf(0x00, 0x02, 0x01)))
    }
}
