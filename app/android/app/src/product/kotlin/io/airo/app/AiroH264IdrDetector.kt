package io.airo.app

/**
 * Scans H.264 Annex-B elementary-stream bytes (as extracted from PES
 * payloads on the video PID) for the start of an IDR NAL unit (NAL
 * unit type 5 -- ISO/IEC 14496-10). Task 4 of the splice plan.
 *
 * Stateful across [feed] calls so a start code split across two TS
 * packets is still detected -- keeps only the last 3 bytes as
 * carry-over, never buffers unbounded data. Handles both the 3-byte
 * (`00 00 01`) and 4-byte (`00 00 00 01`) Annex-B start code forms
 * without special-casing: the 4-byte form always contains the 3-byte
 * pattern starting one byte later.
 */
class AiroH264IdrDetector {
    private var tail = ByteArray(0)

    /** True the moment an IDR NAL start is found within [bytes]
     * (bridging a start code split across the previous call's
     * boundary via the carried-over tail). */
    fun feed(bytes: ByteArray): Boolean {
        val combined = if (tail.isEmpty()) bytes else tail + bytes
        var found = false
        var i = 0
        while (i + 3 <= combined.size) {
            val isStartCode = combined[i] == 0.toByte() &&
                combined[i + 1] == 0.toByte() &&
                combined[i + 2] == 1.toByte()
            if (isStartCode && i + 3 < combined.size) {
                val nalType = combined[i + 3].toInt() and 0x1F
                if (nalType == 5) {
                    found = true
                    break
                }
            }
            i++
        }
        tail = if (combined.size >= 3) combined.copyOfRange(combined.size - 3, combined.size) else combined
        return found
    }

    fun reset() {
        tail = ByteArray(0)
    }
}
