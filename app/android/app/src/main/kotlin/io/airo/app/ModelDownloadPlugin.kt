package io.airo.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.core.app.NotificationCompat
import androidx.work.*
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.File
import java.io.IOException

class ModelDownloadPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "ModelDownloadPlugin"
        private var progressSink: EventChannel.EventSink? = null

        fun updateProgress(
            modelId: String,
            status: String,
            downloaded: Long,
            total: Long,
            speed: Double,
            error: String? = null
        ) {
            val progressMap = mapOf(
                "modelId" to modelId,
                "status" to status,
                "downloadedBytes" to downloaded,
                "totalBytes" to total,
                "speedBytesPerSecond" to speed,
                "error" to error
            )
            Handler(Looper.getMainLooper()).post {
                progressSink?.success(progressMap)
            }
        }
    }

    val progressStreamHandler = object : EventChannel.StreamHandler {
        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            progressSink = events
        }

        override fun onCancel(arguments: Any?) {
            progressSink = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startDownload" -> startDownload(call, result)
            "cancelDownload" -> cancelDownload(call, result)
            "getFreeDiskSpace" -> getFreeDiskSpace(result)
            else -> result.notImplemented()
        }
    }

    private fun startDownload(call: MethodCall, result: MethodChannel.Result) {
        val modelId = call.argument<String>("modelId")
        val url = call.argument<String>("url")
        val filePath = call.argument<String>("filePath")

        if (modelId == null || url == null || filePath == null) {
            result.error("INVALID_ARGUMENTS", "modelId, url, and filePath are required", null)
            return
        }

        val data = workDataOf(
            "modelId" to modelId,
            "url" to url,
            "filePath" to filePath
        )

        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()

        val downloadWork = OneTimeWorkRequestBuilder<ModelDownloadWorker>()
            .setInputData(data)
            .setConstraints(constraints)
            .addTag(modelId)
            .build()

        WorkManager.getInstance(context).enqueueUniqueWork(
            modelId,
            ExistingWorkPolicy.REPLACE,
            downloadWork
        )

        result.success(true)
    }

    private fun cancelDownload(call: MethodCall, result: MethodChannel.Result) {
        val modelId = call.argument<String>("modelId")
        if (modelId == null) {
            result.error("INVALID_ARGUMENTS", "modelId is required", null)
            return
        }

        WorkManager.getInstance(context).cancelUniqueWork(modelId)
        result.success(true)
    }

    private fun getFreeDiskSpace(result: MethodChannel.Result) {
        try {
            val stat = StatFs(context.filesDir.path)
            val bytesAvailable = stat.blockSizeLong * stat.availableBlocksLong
            result.success(bytesAvailable)
        } catch (e: Exception) {
            result.error("DISK_SPACE_ERROR", e.message, null)
        }
    }
}

class ModelDownloadWorker(
    private val context: Context,
    parameters: WorkerParameters
) : CoroutineWorker(context, parameters) {

    override suspend fun doWork(): Result {
        val modelId = inputData.getString("modelId") ?: return Result.failure()
        val url = inputData.getString("url") ?: return Result.failure()
        val filePath = inputData.getString("filePath") ?: return Result.failure()

        val notificationId = modelId.hashCode()
        setForeground(createForegroundInfo(modelId, "Starting download...", 0, 0))

        val tempFile = File("$filePath.tmp")
        try {
            tempFile.parentFile?.mkdirs()

            val client = OkHttpClient.Builder()
                .followRedirects(true)
                .followSslRedirects(true)
                .build()

            val request = Request.Builder()
                .url(url)
                .build()

            var lastProgressUpdate = 0L
            var lastBytes = 0L
            var lastTime = System.currentTimeMillis()
            var currentSpeed = 0.0

            client.newCall(request).execute().use { response ->
                if (!response.isSuccessful) throw IOException("Unexpected HTTP code $response")
                val body = response.body ?: throw IOException("Empty response body")
                val totalBytes = body.contentLength().takeIf { it > 0 } ?: 0L

                body.byteStream().use { input ->
                    tempFile.outputStream().use { output ->
                        val buffer = ByteArray(64 * 1024)
                        var bytesRead: Int
                        var downloadedBytes = 0L

                        while (input.read(buffer).also { bytesRead = it } != -1) {
                            if (isStopped) {
                                ModelDownloadPlugin.updateProgress(modelId, "cancelled", downloadedBytes, totalBytes, 0.0)
                                tempFile.delete()
                                return Result.failure()
                            }

                            output.write(buffer, 0, bytesRead)
                            downloadedBytes += bytesRead

                            val now = System.currentTimeMillis()
                            val elapsed = now - lastTime

                            if (now - lastProgressUpdate > 500) {
                                if (elapsed >= 500) {
                                    val bytesPerMs = (downloadedBytes - lastBytes).toDouble() / elapsed
                                    currentSpeed = bytesPerMs * 1000.0
                                    lastBytes = downloadedBytes
                                    lastTime = now
                                }

                                val percent = if (totalBytes > 0) (downloadedBytes * 100 / totalBytes).toInt() else 0
                                setForeground(createForegroundInfo(modelId, "Downloading: $percent%", downloadedBytes, totalBytes))

                                ModelDownloadPlugin.updateProgress(modelId, "downloading", downloadedBytes, totalBytes, currentSpeed)
                                lastProgressUpdate = now
                            }
                        }
                    }
                }

                val destFile = File(filePath)
                if (destFile.exists()) destFile.delete()
                if (!tempFile.renameTo(destFile)) {
                    throw IOException("Failed to rename temp file to destination")
                }

                ModelDownloadPlugin.updateProgress(modelId, "completed", totalBytes, totalBytes, 0.0)
                return Result.success()
            }
        } catch (e: Exception) {
            tempFile.delete()
            ModelDownloadPlugin.updateProgress(modelId, "failed", 0, 0, 0.0, e.message)
            return Result.failure()
        }
    }

    private fun createForegroundInfo(
        modelId: String,
        contentText: String,
        downloaded: Long,
        total: Long
    ): ForegroundInfo {
        val channelId = "model_download_channel"
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Model Downloads", NotificationManager.IMPORTANCE_LOW)
            notificationManager.createNotificationChannel(channel)
        }

        val max = if (total > 0) 100 else 0
        val progress = if (total > 0) (downloaded * 100 / total).toInt() else 0

        val notification = NotificationCompat.Builder(context, channelId)
            .setContentTitle("Downloading AI Model ($modelId)")
            .setContentText(contentText)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setOngoing(true)
            .setProgress(max, progress, total <= 0)
            .build()

        val serviceType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
        } else {
            0
        }

        return ForegroundInfo(modelId.hashCode(), notification, serviceType)
    }
}
