package io.airo.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroTsPacketParserTest {
    @Test
    fun `rejects a packet with the wrong length`() {
        assertNull(AiroTsPacketParser.parse(ByteArray(100)))
    }

    @Test
    fun `rejects a packet with a bad sync byte`() {
        val packet = ByteArray(188) { 0x00 }
        assertNull(AiroTsPacketParser.parse(packet))
    }

    @Test
    fun `rejects a packet with the transport error indicator set`() {
        val packet = ByteArray(188)
        packet[0] = 0x47
        packet[1] = 0x80.toByte() // TEI bit set
        assertNull(AiroTsPacketParser.parse(packet))
    }

    @Test
    fun `extracts pid and payload-unit-start for a payload-only packet`() {
        val packet = ByteArray(188)
        packet[0] = 0x47
        packet[1] = 0x40 // PUSI=1, pid high=0
        packet[2] = 0x20 // pid low
        packet[3] = 0x10 // adaptation_field_control=01 (payload only)
        packet[4] = 0x11 // first payload byte

        val parsed = AiroTsPacketParser.parse(packet)!!
        assertEquals(0x20, parsed.pid)
        assertTrue(parsed.payloadUnitStart)
        assertEquals(184, parsed.payload.size)
        assertEquals(0x11, parsed.payload[0].toInt() and 0xFF)
    }

    @Test
    fun `skips a present adaptation field before returning payload`() {
        val packet = ByteArray(188)
        packet[0] = 0x47
        packet[1] = 0x00
        packet[2] = 0x21
        packet[3] = 0x30 // adaptation_field_control=11 (adaptation + payload)
        packet[4] = 5 // adaptation_field_length
        // 5 bytes of adaptation field follow at [5..9]
        packet[10] = 0x22 // first real payload byte after adaptation field

        val parsed = AiroTsPacketParser.parse(packet)!!
        assertEquals(0x22, parsed.payload[0].toInt() and 0xFF)
    }

    @Test
    fun `an adaptation-field-only packet has empty payload`() {
        val packet = ByteArray(188)
        packet[0] = 0x47
        packet[1] = 0x00
        packet[2] = 0x21
        packet[3] = 0x20 // adaptation_field_control=10 (adaptation only)
        packet[4] = 183.toByte() // fills the rest of the packet

        val parsed = AiroTsPacketParser.parse(packet)!!
        assertEquals(0, parsed.payload.size)
    }
}
