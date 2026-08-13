package io.airo.app

/**
 * One parsed 188-byte MPEG-TS packet (ISO/IEC 13818-1). Task 4 of
 * tasks/tv-zero-copy-cast-splice-plan.md. Pure -- no Media3 dependency,
 * AD-P2B.4.
 */
data class AiroTsPacket(
    val pid: Int,
    val payloadUnitStart: Boolean,
    val payload: ByteArray,
)

/** Parses raw 188-byte TS packets. Never throws -- this parses
 * untrusted network data (Task 4 acceptance criterion); anything
 * malformed resolves to `null` rather than an exception. */
object AiroTsPacketParser {
    const val PACKET_SIZE = 188
    private const val SYNC_BYTE = 0x47

    fun parse(packet: ByteArray): AiroTsPacket? {
        if (packet.size != PACKET_SIZE) return null
        if (packet[0].toInt() and 0xFF != SYNC_BYTE) return null

        val byte1 = packet[1].toInt() and 0xFF
        val transportErrorIndicator = (byte1 and 0x80) != 0
        if (transportErrorIndicator) return null
        val payloadUnitStart = (byte1 and 0x40) != 0
        val pid = ((byte1 and 0x1F) shl 8) or (packet[2].toInt() and 0xFF)

        val byte3 = packet[3].toInt() and 0xFF
        val adaptationFieldControl = (byte3 shr 4) and 0x03
        if (adaptationFieldControl == 0) return null // reserved value

        var offset = 4
        if (adaptationFieldControl == 2 || adaptationFieldControl == 3) {
            val adaptationFieldLength = packet[4].toInt() and 0xFF
            offset = 5 + adaptationFieldLength
            if (offset > PACKET_SIZE) return null
        }
        if (adaptationFieldControl == 2) {
            return AiroTsPacket(pid, payloadUnitStart, ByteArray(0))
        }
        if (offset > PACKET_SIZE) return null
        return AiroTsPacket(pid, payloadUnitStart, packet.copyOfRange(offset, PACKET_SIZE))
    }
}
