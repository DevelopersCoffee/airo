package io.airo.platform_text_embeddings

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmbeddingContractsTest {
    @Test
    fun `text validation uses UTF-8 bytes and rejects blank input`() {
        assertFalse(EmbeddingRequestValidator.isValidText(" \n "))
        assertTrue(EmbeddingRequestValidator.isValidText("a".repeat(50 * 1024)))
        assertFalse(EmbeddingRequestValidator.isValidText("é".repeat(25_601)))
    }

    @Test
    fun `model metadata accepts only reviewed dimensions and hashes`() {
        assertTrue(EmbeddingRequestValidator.isSupportedDimensions(256))
        assertTrue(EmbeddingRequestValidator.isSupportedDimensions(384))
        assertFalse(EmbeddingRequestValidator.isSupportedDimensions(512))
        assertEquals(384, EmbeddingRequestValidator.exactDimensions(384))
        assertEquals(384, EmbeddingRequestValidator.exactDimensions(384L))
        assertEquals(null, EmbeddingRequestValidator.exactDimensions(384.5))
        assertEquals(
            null,
            EmbeddingRequestValidator.exactDimensions(Long.MAX_VALUE),
        )
        assertTrue(EmbeddingRequestValidator.isSha256("a".repeat(64)))
        assertFalse(EmbeddingRequestValidator.isSha256("g".repeat(64)))
    }

    @Test
    fun `failure replies contain only stable redacted fields`() {
        assertEquals(
            mapOf(
                "status" to "failure",
                "code" to "model_integrity_mismatch",
            ),
            PlatformReplies.failure(EmbeddingFailure.MODEL_INTEGRITY_MISMATCH),
        )
    }
}
