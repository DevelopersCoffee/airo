package io.airo.app

/**
 * Parses PSI (Program Specific Information) sections -- PAT and PMT --
 * per ISO/IEC 13818-1. Task 4 of the splice plan.
 *
 * Takes a single TS packet's payload with `payloadUnitStart=true`
 * (pointer_field is stripped internally). Reassembling a PSI section
 * split across multiple TS packets is out of scope -- broadcast
 * PAT/PMT sections are small and near-universally fit in one packet;
 * this simply returns `null` rather than crashing if a section runs
 * past the packet it was given. Never throws on malformed input.
 */
object AiroTsPsiParser {
    private const val PAT_TABLE_ID = 0x00
    private const val PMT_TABLE_ID = 0x02
    private const val CRC_LENGTH = 4

    // H.264/AVC video only (Task 4's own scope -- IDR detection assumes
    // H.264 Annex-B NAL units). H.265/other video stream types would
    // need their own IDR-equivalent detector, not just a wider set here.
    private val VIDEO_STREAM_TYPES = setOf(0x1B)

    fun findPmtPid(payload: ByteArray): Int? {
        val section = stripPointerField(payload) ?: return null
        if (section.isEmpty() || (section[0].toInt() and 0xFF) != PAT_TABLE_ID) return null
        val length = sectionLength(section) ?: return null
        val programsEnd = 3 + length - CRC_LENGTH
        if (programsEnd > section.size) return null

        var offset = 8 // past table_id, section_length, tsid, version, section_number, last_section_number
        while (offset + 4 <= programsEnd) {
            val programNumber = ((section[offset].toInt() and 0xFF) shl 8) or (section[offset + 1].toInt() and 0xFF)
            val pid = ((section[offset + 2].toInt() and 0x1F) shl 8) or (section[offset + 3].toInt() and 0xFF)
            if (programNumber != 0) return pid
            offset += 4
        }
        return null
    }

    fun findVideoPid(payload: ByteArray): Int? {
        val section = stripPointerField(payload) ?: return null
        if (section.isEmpty() || (section[0].toInt() and 0xFF) != PMT_TABLE_ID) return null
        val length = sectionLength(section) ?: return null
        val sectionEnd = 3 + length - CRC_LENGTH
        if (sectionEnd > section.size || sectionEnd < 12) return null

        val programInfoLength = ((section[10].toInt() and 0x0F) shl 8) or (section[11].toInt() and 0xFF)
        var offset = 12 + programInfoLength
        while (offset + 5 <= sectionEnd) {
            val streamType = section[offset].toInt() and 0xFF
            val pid = ((section[offset + 1].toInt() and 0x1F) shl 8) or (section[offset + 2].toInt() and 0xFF)
            val esInfoLength = ((section[offset + 3].toInt() and 0x0F) shl 8) or (section[offset + 4].toInt() and 0xFF)
            if (streamType in VIDEO_STREAM_TYPES) return pid
            offset += 5 + esInfoLength
        }
        return null
    }

    private fun stripPointerField(payload: ByteArray): ByteArray? {
        if (payload.isEmpty()) return null
        val pointerField = payload[0].toInt() and 0xFF
        val start = 1 + pointerField
        if (start > payload.size) return null
        return payload.copyOfRange(start, payload.size)
    }

    private fun sectionLength(section: ByteArray): Int? {
        if (section.size < 3) return null
        return ((section[1].toInt() and 0x0F) shl 8) or (section[2].toInt() and 0xFF)
    }
}
