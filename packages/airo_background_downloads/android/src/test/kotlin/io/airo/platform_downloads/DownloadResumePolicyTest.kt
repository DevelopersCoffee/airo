package io.airo.platform_downloads

import java.io.File
import java.nio.file.Files
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DownloadResumePolicyTest {
    @Test
    fun partialResponseAppendsFromExistingOffset() {
        assertEquals(
            ResumeDecision.Append(offset = 512L),
            DownloadResumePolicy.decide(existingBytes = 512L, responseCode = 206),
        )
    }

    @Test
    fun fullResponseForPartialDownloadRequiresExplicitRestart() {
        assertEquals(
            ResumeDecision.Unsupported,
            DownloadResumePolicy.decide(existingBytes = 512L, responseCode = 200),
        )
    }

    @Test
    fun initialSuccessfulResponseStartsFresh() {
        assertEquals(
            ResumeDecision.StartFresh,
            DownloadResumePolicy.decide(existingBytes = 0L, responseCode = 200),
        )
    }

    @Test
    fun sha256VerificationMatchesKnownFixture() {
        val directory = Files.createTempDirectory("platform-downloads").toFile()
        val artifact = File(directory, "fixture.bin")
        artifact.writeText("airo")

        assertTrue(
            FileIntegrity.matchesSha256(
                artifact,
                "f92f191e8d784a2f82b95f4828338dd3c0c9f74b0320dd931772b42c6c5cbb63",
            ),
        )
        assertFalse(
            FileIntegrity.matchesSha256(
                artifact,
                "0000000000000000000000000000000000000000000000000000000000000000",
            ),
        )

        directory.deleteRecursively()
    }
}
