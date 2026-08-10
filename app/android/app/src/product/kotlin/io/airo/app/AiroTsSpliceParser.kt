package io.airo.app

/**
 * Task 4 of tasks/tv-zero-copy-cast-splice-plan.md. Feed raw MPEG-TS
 * bytes (arbitrary chunk boundaries, exactly as they arrive off the
 * network) and get back the index of the first TS packet, since
 * construction or the last [reset], whose payload contains the start
 * of an H.264 IDR NAL unit on the program's video elementary stream --
 * PAT to find the PMT's PID, PMT to find the video PID, then scan that
 * PID's payload. Null until that chain resolves.
 *
 * Encrypted/scrambled streams and non-H.264 video never produce a
 * video-PID match against [AiroTsPsiParser]'s H.264-only stream type
 * set, so this simply stays null forever for them -- callers must have
 * their own bounded timeout ([AiroSpliceDecision], Task 0) rather than
 * waiting on this indefinitely; detecting scrambling explicitly and
 * failing over immediately (rather than scanning scrambled bytes for a
 * NAL pattern that can never legitimately appear) is flagged in the
 * plan's risk table as future work, not solved here.
 */
class AiroTsSpliceParser {
    private val packetizer = AiroTsPacketizer()
    private val idrDetector = AiroH264IdrDetector()
    private var pmtPid: Int? = null
    private var videoPid: Int? = null
    private var packetIndex = -1

    fun feed(chunk: ByteArray): Int? {
        for (rawPacket in packetizer.append(chunk)) {
            packetIndex++
            val packet = AiroTsPacketParser.parse(rawPacket) ?: continue

            if (pmtPid == null && packet.pid == PAT_PID && packet.payloadUnitStart) {
                pmtPid = AiroTsPsiParser.findPmtPid(packet.payload)
            }

            val currentPmtPid = pmtPid
            if (videoPid == null && currentPmtPid != null &&
                packet.pid == currentPmtPid && packet.payloadUnitStart
            ) {
                videoPid = AiroTsPsiParser.findVideoPid(packet.payload)
            }

            val currentVideoPid = videoPid
            if (currentVideoPid != null && packet.pid == currentVideoPid) {
                val esPayload = stripPesHeaderIfPresent(packet.payload, packet.payloadUnitStart)
                if (idrDetector.feed(esPayload)) {
                    return packetIndex
                }
            }
        }
        return null
    }

    fun reset() {
        pmtPid = null
        videoPid = null
        packetIndex = -1
        idrDetector.reset()
    }

    /** Only the packet that starts a new PES packet (`payloadUnitStart`)
     * carries a PES header; continuation packets on the same PID are
     * raw elementary-stream bytes already. Without stripping this, the
     * PES packet_start_code_prefix (`00 00 01`) plus a video stream_id
     * in `0xE0..0xEF` can coincidentally false-positive as an IDR NAL
     * start, since `stream_id & 0x1F` covers the full 0-31 range
     * including 5 -- this is a real false-positive risk, not a
     * theoretical one, and is why this strip happens before the bytes
     * ever reach [AiroH264IdrDetector]. Only handles the standard PES
     * header shape (stream_id not one of the few reserved ids with a
     * different layout, e.g. padding/private streams) -- sufficient
     * for video elementary streams, which is all this detector cares
     * about. */
    private fun stripPesHeaderIfPresent(payload: ByteArray, isPayloadStart: Boolean): ByteArray {
        if (!isPayloadStart || payload.size < 9) return payload
        val hasPesPrefix = payload[0] == 0.toByte() && payload[1] == 0.toByte() && payload[2] == 1.toByte()
        if (!hasPesPrefix) return payload
        val headerDataLength = payload[8].toInt() and 0xFF
        val esStart = 9 + headerDataLength
        if (esStart > payload.size) return payload
        return payload.copyOfRange(esStart, payload.size)
    }

    private companion object {
        const val PAT_PID = 0x0000
    }
}
