package io.airo.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AiroSpatialPcmTapTest {
    @Test
    fun `setSpatialAudioMode updates tap status detail`() {
        AiroSpatialPcmTap.setSpatialAudioMode("original")
        val original = AiroSpatialPcmTap.tapStatusMap()
        assertEquals("pcm_after_decode", original["tapKind"])
        assertTrue(
            (original["detailCodes"] as List<*>).any { it.toString().contains("original") },
        )

        AiroSpatialPcmTap.setSpatialAudioMode("spatial")
        val spatial = AiroSpatialPcmTap.tapStatusMap()
        assertTrue(
            (spatial["detailCodes"] as List<*>).any { it.toString().contains("spatial") },
        )
    }
}
