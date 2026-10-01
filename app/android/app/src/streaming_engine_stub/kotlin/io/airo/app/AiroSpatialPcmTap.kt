package io.airo.app

/**
 * Non-TV stub: no Media3 PCM tap is compiled into phone/Coins builds. The Dart
 * contract degrades to [tapKind]=unavailable via [AiroSpatialAudioPlugin].
 */
object AiroSpatialPcmTap {
    fun setSpatialAudioMode(@Suppress("UNUSED_PARAMETER") stableId: String) {}

    fun tapStatusMap(): Map<String, Any?> {
        return mapOf(
            "backend" to "media3",
            "tapKind" to "unavailable",
            "processorInstalled" to false,
            "framesProcessed" to 0,
            "detailCodes" to listOf("tv_variant_only"),
        )
    }
}
