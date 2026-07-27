package io.airo.platform_downloads

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.StatFs
import androidx.core.app.NotificationCompat
import androidx.work.CoroutineWorker
import androidx.work.ForegroundInfo
import androidx.work.WorkerParameters
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
import kotlin.math.max

internal class ProgressiveDownloadWorker(
    private val context: Context,
    parameters: WorkerParameters,
) : CoroutineWorker(context, parameters) {
    private val store = DownloadStateStore(context)

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val artifactId = inputData.getString("artifactId") ?: return@withContext Result.failure()
        val source = inputData.getString("source") ?: return@withContext Result.failure()
        val destinationPath =
            inputData.getString("destinationPath") ?: return@withContext Result.failure()
        val generation = inputData.getInt("generation", 0)
        val retryCount = inputData.getInt("retryCount", 0)
        val expectedBytes =
            inputData.getLong("expectedBytes", -1L).takeIf { it > 0 }
        val expectedSha256 = inputData.getString("expectedSha256")
        val displayName = inputData.getString("displayName") ?: artifactId
        val destination = File(destinationPath)
        val partial = File("$destinationPath.part")

        if (!store.isCurrentGeneration(artifactId, generation)) {
            cleanupIfCancelled(artifactId, partial)
            return@withContext Result.success()
        }

        destination.parentFile?.mkdirs()
        val existingBytes = partial.takeIf(File::exists)?.length() ?: 0L
        if (expectedBytes != null) {
            val remainingBytes = (expectedBytes - existingBytes).coerceAtLeast(0)
            val availableBytes = StatFs(destination.parentFile?.path ?: context.dataDir.path)
                .availableBytes
            if (availableBytes < remainingBytes) {
                fail(
                    artifactId = artifactId,
                    partial = partial,
                    retryCount = retryCount,
                    code = "insufficient_storage",
                    message = "The artifact does not fit in available storage.",
                )
                return@withContext Result.failure()
            }
        }
        store.updateState(
            artifactId = artifactId,
            status = "downloading",
            downloadedBytes = existingBytes,
            totalBytes = expectedBytes ?: 0,
            retryCount = retryCount,
            canResume = existingBytes > 0,
        )
        setForeground(
            createForegroundInfo(
                artifactId = artifactId,
                displayName = displayName,
                downloadedBytes = existingBytes,
                totalBytes = expectedBytes ?: 0,
            ),
        )

        val request = Request.Builder()
            .url(source)
            .apply {
                if (existingBytes > 0) {
                    header("Range", "bytes=$existingBytes-")
                }
            }
            .build()

        try {
            HTTP_CLIENT.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    fail(
                        artifactId = artifactId,
                        partial = partial,
                        retryCount = retryCount,
                        code = "transport",
                        message = "Download server returned HTTP ${response.code}.",
                    )
                    return@withContext Result.failure()
                }

                when (
                    val resumeDecision =
                        DownloadResumePolicy.decide(existingBytes, response.code)
                ) {
                    ResumeDecision.Unsupported -> {
                        fail(
                            artifactId = artifactId,
                            partial = partial,
                            retryCount = retryCount,
                            code = "resume_not_supported",
                            message = "The server could not resume this partial download.",
                        )
                        return@withContext Result.failure()
                    }
                    else -> transfer(
                        artifactId = artifactId,
                        generation = generation,
                        retryCount = retryCount,
                        displayName = displayName,
                        responseBody = response.body
                            ?: throw IOException("Download response was empty."),
                        append = resumeDecision is ResumeDecision.Append,
                        existingBytes = existingBytes,
                        expectedBytes = expectedBytes,
                        partial = partial,
                    )
                }
            }

            if (!store.isCurrentGeneration(artifactId, generation)) {
                cleanupIfCancelled(artifactId, partial)
                return@withContext Result.success()
            }

            store.updateState(
                artifactId = artifactId,
                status = "verifying",
                downloadedBytes = partial.length(),
                totalBytes = expectedBytes ?: partial.length(),
                retryCount = retryCount,
                canResume = false,
            )
            if (expectedBytes != null && partial.length() != expectedBytes) {
                partial.delete()
                fail(
                    artifactId = artifactId,
                    partial = partial,
                    retryCount = retryCount,
                    code = "integrity_mismatch",
                    message = "Downloaded byte count did not match the expected artifact size.",
                    canResume = false,
                )
                return@withContext Result.failure()
            }
            if (
                expectedSha256 != null &&
                !FileIntegrity.matchesSha256(partial, expectedSha256)
            ) {
                partial.delete()
                fail(
                    artifactId = artifactId,
                    partial = partial,
                    retryCount = retryCount,
                    code = "integrity_mismatch",
                    message = "Downloaded artifact failed SHA-256 verification.",
                    canResume = false,
                )
                return@withContext Result.failure()
            }

            promoteAtomically(partial, destination)
            store.updateState(
                artifactId = artifactId,
                status = "completed",
                downloadedBytes = destination.length(),
                totalBytes = expectedBytes ?: destination.length(),
                retryCount = retryCount,
            )
            Result.success()
        } catch (_: Exception) {
            fail(
                artifactId = artifactId,
                partial = partial,
                retryCount = retryCount,
                code = "transport",
                message = "Download was interrupted.",
            )
            Result.failure()
        }
    }

    private suspend fun transfer(
        artifactId: String,
        generation: Int,
        retryCount: Int,
        displayName: String,
        responseBody: okhttp3.ResponseBody,
        append: Boolean,
        existingBytes: Long,
        expectedBytes: Long?,
        partial: File,
    ) {
        val responseBytes = responseBody.contentLength().coerceAtLeast(0)
        val totalBytes = expectedBytes ?: (existingBytes + responseBytes)
        var downloadedBytes = existingBytes
        var lastBytes = existingBytes
        var lastUpdateMillis = System.currentTimeMillis()

        responseBody.byteStream().use { input ->
            FileOutputStream(partial, append).use { output ->
                val buffer = ByteArray(64 * 1024)
                while (true) {
                    if (!store.isCurrentGeneration(artifactId, generation)) {
                        return
                    }
                    val count = input.read(buffer)
                    if (count < 0) break
                    output.write(buffer, 0, count)
                    downloadedBytes += count
                    val now = System.currentTimeMillis()
                    val elapsedMillis = max(1L, now - lastUpdateMillis)
                    if (elapsedMillis >= PROGRESS_INTERVAL_MILLIS) {
                        val speed =
                            (downloadedBytes - lastBytes).toDouble() * 1000.0 / elapsedMillis
                        store.updateState(
                            artifactId = artifactId,
                            status = "downloading",
                            downloadedBytes = downloadedBytes,
                            totalBytes = totalBytes,
                            speedBytesPerSecond = speed,
                            retryCount = retryCount,
                            canResume = downloadedBytes > 0,
                        )
                        setForeground(
                            createForegroundInfo(
                                artifactId = artifactId,
                                displayName = displayName,
                                downloadedBytes = downloadedBytes,
                                totalBytes = totalBytes,
                            ),
                        )
                        lastBytes = downloadedBytes
                        lastUpdateMillis = now
                    }
                }
                output.fd.sync()
            }
        }
    }

    private fun cleanupIfCancelled(artifactId: String, partial: File) {
        if (store.status(artifactId) == "cancelled") {
            partial.delete()
        }
    }

    private fun fail(
        artifactId: String,
        partial: File,
        retryCount: Int,
        code: String,
        message: String,
        canResume: Boolean = partial.exists() && partial.length() > 0,
    ) {
        store.updateState(
            artifactId = artifactId,
            status = "failed",
            downloadedBytes = partial.length(),
            retryCount = retryCount,
            failureCode = code,
            failureMessage = message,
            canResume = canResume,
        )
    }

    private fun promoteAtomically(partial: File, destination: File) {
        try {
            Files.move(
                partial.toPath(),
                destination.toPath(),
                StandardCopyOption.ATOMIC_MOVE,
                StandardCopyOption.REPLACE_EXISTING,
            )
        } catch (_: Exception) {
            Files.move(
                partial.toPath(),
                destination.toPath(),
                StandardCopyOption.REPLACE_EXISTING,
            )
        }
    }

    private fun createForegroundInfo(
        artifactId: String,
        displayName: String,
        downloadedBytes: Long,
        totalBytes: Long,
    ): ForegroundInfo {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    NOTIFICATION_CHANNEL_ID,
                    "Airo downloads",
                    NotificationManager.IMPORTANCE_LOW,
                ),
            )
        }
        val percent =
            if (totalBytes > 0) ((downloadedBytes * 100) / totalBytes).toInt() else 0
        val notification = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(displayName.take(80))
            .setContentText(if (totalBytes > 0) "Downloading $percent%" else "Downloading")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setProgress(100, percent, totalBytes <= 0)
            .build()
        val notificationId = artifactId.hashCode()
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(
                notificationId,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            ForegroundInfo(notificationId, notification)
        }
    }

    companion object {
        // WorkManager is the Android-recommended persistent background-work API.
        // Source: https://developer.android.com/develop/background-work/background-tasks/persistent
        private val HTTP_CLIENT = OkHttpClient.Builder()
            .followRedirects(true)
            .followSslRedirects(false)
            .build()
        private const val PROGRESS_INTERVAL_MILLIS = 500L
        private const val NOTIFICATION_CHANNEL_ID = "airo_platform_downloads"
    }
}
