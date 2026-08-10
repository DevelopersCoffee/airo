package io.airo.app

/**
 * Splits arbitrary-sized byte chunks (as they arrive off the network,
 * with no guarantee of TS-packet alignment) into sync-aligned 188-byte
 * MPEG-TS packets, buffering leftovers across calls. Task 4 of the
 * splice plan.
 *
 * Resyncs by scanning forward for a sync byte (0x47) whenever the
 * expected packet boundary doesn't hold one, and additionally checks
 * for a second sync byte 188 bytes later before committing to an
 * offset -- a lone 0x47 inside payload bytes is common, but two 0x47s
 * exactly 188 bytes apart essentially never happens by chance.
 *
 * Not optimized for the sustained network-read hot path (`buffer +=
 * chunk` reallocates each call) -- flagged for chief-performance-officer
 * review at the splice plan's final checkpoint if this proves to
 * matter in practice, per the plan's own risk table.
 */
class AiroTsPacketizer {
    private var buffer = ByteArray(0)

    fun append(chunk: ByteArray): List<ByteArray> {
        buffer += chunk
        val packets = mutableListOf<ByteArray>()
        var offset = 0
        while (offset < buffer.size) {
            if ((buffer[offset].toInt() and 0xFF) != 0x47) {
                offset++
                continue
            }
            val next = offset + AiroTsPacketParser.PACKET_SIZE
            if (next < buffer.size && (buffer[next].toInt() and 0xFF) != 0x47) {
                offset++
                continue
            }
            if (offset + AiroTsPacketParser.PACKET_SIZE > buffer.size) break
            packets.add(buffer.copyOfRange(offset, offset + AiroTsPacketParser.PACKET_SIZE))
            offset += AiroTsPacketParser.PACKET_SIZE
        }
        buffer = if (offset >= buffer.size) ByteArray(0) else buffer.copyOfRange(offset, buffer.size)
        return packets
    }
}
