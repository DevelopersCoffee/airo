package io.airo.platform_downloads

import java.io.File
import java.io.FileInputStream
import java.security.MessageDigest

internal sealed interface ResumeDecision {
    data object StartFresh : ResumeDecision

    data class Append(val offset: Long) : ResumeDecision

    data object Unsupported : ResumeDecision
}

internal object DownloadResumePolicy {
    fun decide(existingBytes: Long, responseCode: Int): ResumeDecision {
        require(existingBytes >= 0) { "existingBytes must not be negative" }
        return when {
            existingBytes == 0L && responseCode in 200..299 ->
                ResumeDecision.StartFresh
            existingBytes > 0L && responseCode == 206 ->
                ResumeDecision.Append(existingBytes)
            existingBytes > 0L ->
                ResumeDecision.Unsupported
            else ->
                ResumeDecision.Unsupported
        }
    }
}

internal object FileIntegrity {
    fun matchesSha256(file: File, expectedSha256: String): Boolean {
        val digest = MessageDigest.getInstance("SHA-256")
        FileInputStream(file).use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val bytesRead = input.read(buffer)
                if (bytesRead < 0) break
                digest.update(buffer, 0, bytesRead)
            }
        }
        val actual = digest.digest().joinToString(separator = "") { byte ->
            "%02x".format(byte)
        }
        return actual.equals(expectedSha256, ignoreCase = true)
    }
}
