package io.airo.platform_text_embeddings

import java.nio.charset.StandardCharsets

internal enum class EmbeddingFailure(
    val stableId: String,
) {
    PLATFORM_UNAVAILABLE("platform_unavailable"),
    MODEL_MISSING("model_missing"),
    MODEL_INTEGRITY_MISMATCH("model_integrity_mismatch"),
    UNSUPPORTED_DIMENSIONS("unsupported_dimensions"),
    INVALID_INPUT("invalid_input"),
    INITIALIZATION_FAILED("initialization_failed"),
    INFERENCE_FAILED("inference_failed"),
    CANCELLED("cancelled"),
    PROVIDER_CLOSED("provider_closed"),
}

internal object EmbeddingRequestValidator {
    private const val MAX_TEXT_BYTES = 50 * 1024
    private val sha256Pattern = Regex("^[0-9a-fA-F]{64}$")

    fun isValidText(text: String): Boolean =
        text.isNotBlank() &&
            text.toByteArray(StandardCharsets.UTF_8).size <= MAX_TEXT_BYTES

    fun isSupportedDimensions(dimensions: Int): Boolean =
        dimensions == 256 || dimensions == 384

    fun exactDimensions(value: Any?): Int? =
        when (value) {
            is Int -> value
            is Long -> value.toInt().takeIf { it.toLong() == value }
            else -> null
        }

    fun isSha256(value: String): Boolean = sha256Pattern.matches(value)
}

internal object PlatformReplies {
    fun failure(code: EmbeddingFailure): Map<String, String> =
        mapOf(
            "status" to "failure",
            "code" to code.stableId,
        )

    fun ready(sessionId: String): Map<String, String> =
        mapOf(
            "status" to "ready",
            "sessionId" to sessionId,
        )

    fun success(values: List<Double>): Map<String, Any> =
        mapOf(
            "status" to "success",
            "values" to values,
        )

    fun closed(): Map<String, String> = mapOf("status" to "closed")
}
