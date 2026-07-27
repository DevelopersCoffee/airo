package io.airo.platform_downloads

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import androidx.work.Constraints
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class PlatformDownloadsPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler {
    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var store: DownloadStateStore
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var lastEmittedStates: Map<String, String> = emptyMap()

    private val eventPoller = object : Runnable {
        override fun run() {
            val sink = eventSink ?: return
            val states = store.statesInOrder()
            val nextSignatures = mutableMapOf<String, String>()
            states.forEach { state ->
                val artifactId = state["artifactId"] as? String ?: return@forEach
                val signature = state.toSortedMap().toString()
                nextSignatures[artifactId] = signature
                if (lastEmittedStates[artifactId] != signature) {
                    sink.success(state)
                }
            }
            lastEmittedStates = nextSignatures
            handler.postDelayed(this, EVENT_POLL_MILLIS)
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        store = DownloadStateStore(context)
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL)
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL)
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "enqueue" -> enqueue(call, result)
                "pause" -> pause(call, result)
                "resume" -> resume(call, result)
                "retry" -> retry(call, result)
                "cancel" -> cancel(call, result)
                "getQueue" -> result.success(
                    mapOf("entries" to store.statesInOrder()),
                )
                "getAvailableBytes" -> {
                    val stat = StatFs(context.dataDir.path)
                    result.success(stat.availableBytes)
                }
                else -> result.notImplemented()
            }
        } catch (error: IllegalArgumentException) {
            result.error("invalid_request", error.message, null)
        } catch (_: Exception) {
            result.error("platform_unavailable", "Download operation failed.", null)
        }
    }

    private fun enqueue(call: MethodCall, result: MethodChannel.Result) {
        val artifactId = call.requiredString("artifactId")
        validateArtifactId(artifactId)
        val source = call.requiredString("source")
        val destinationPath = call.requiredString("destinationPath")
        validateSource(source)
        validateDestination(destinationPath)
        val status = store.status(artifactId)
        if (status in ACTIVE_STATUSES) {
            result.success(null)
            return
        }
        val request = store.saveNewRequest(
            artifactId = artifactId,
            source = source,
            destinationPath = destinationPath,
            expectedBytes = call.argument<Number>("expectedBytes")?.toLong(),
            expectedSha256 = call.argument<String>("expectedSha256"),
            displayName = call.argument<String>("displayName"),
        )
        store.updateState(
            artifactId = artifactId,
            status = "queued",
            totalBytes = request.expectedBytes ?: 0,
        )
        val queueBlocked = store.statesInOrder().any { it["status"] == "failed" }
        if (!queueBlocked) {
            enqueueWork(request)
        }
        result.success(null)
    }

    private fun pause(call: MethodCall, result: MethodChannel.Result) {
        val artifactId = call.requiredString("artifactId")
        val request = store.invalidateGeneration(artifactId)
        if (request != null && store.status(artifactId) in PAUSABLE_STATUSES) {
            val partial = File("${request.destinationPath}.part")
            store.updateState(
                artifactId = artifactId,
                status = "paused",
                downloadedBytes = partial.length(),
                totalBytes = request.expectedBytes ?: 0,
                retryCount = request.retryCount,
                canResume = partial.exists() && partial.length() > 0,
            )
        }
        result.success(null)
    }

    private fun resume(call: MethodCall, result: MethodChannel.Result) {
        val artifactId = call.requiredString("artifactId")
        val previousStatus = store.status(artifactId)
        if (previousStatus != "paused" && previousStatus != "failed") {
            result.success(null)
            return
        }
        val request = store.nextAttempt(
            artifactId,
            incrementRetry = false,
            moveToEnd = previousStatus == "paused",
        )
            ?: throw IllegalArgumentException("Unknown artifact.")
        store.updateState(
            artifactId = artifactId,
            status = "queued",
            downloadedBytes = File("${request.destinationPath}.part").length(),
            totalBytes = request.expectedBytes ?: 0,
            retryCount = request.retryCount,
            canResume = true,
        )
        if (previousStatus == "failed") {
            rebuildQueuedWork()
        } else {
            enqueueWork(request)
        }
        result.success(null)
    }

    private fun retry(call: MethodCall, result: MethodChannel.Result) {
        val artifactId = call.requiredString("artifactId")
        if (store.status(artifactId) != "failed") {
            result.success(null)
            return
        }
        val current = store.request(artifactId)
            ?: throw IllegalArgumentException("Unknown artifact.")
        val failureCode = store.state(artifactId)?.get("failureCode")
        if (failureCode == "resume_not_supported") {
            File("${current.destinationPath}.part").delete()
        }
        val request = store.nextAttempt(artifactId, incrementRetry = true)
            ?: throw IllegalArgumentException("Unknown artifact.")
        val partialBytes = File("${request.destinationPath}.part").length()
        store.updateState(
            artifactId = artifactId,
            status = "queued",
            downloadedBytes = partialBytes,
            totalBytes = request.expectedBytes ?: 0,
            retryCount = request.retryCount,
            canResume = partialBytes > 0,
        )
        rebuildQueuedWork()
        result.success(null)
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val artifactId = call.requiredString("artifactId")
        val previousStatus = store.status(artifactId)
        val request = store.invalidateGeneration(artifactId)
        if (request != null) {
            val partial = File("${request.destinationPath}.part")
            val deleted = !partial.exists() || partial.delete()
            store.updateState(
                artifactId = artifactId,
                status = if (deleted) "cancelled" else "failed",
                retryCount = request.retryCount,
                failureCode = if (deleted) "cancelled" else "cleanup_failed",
                failureMessage = if (deleted) null else "Partial download cleanup failed.",
            )
            eventSink?.let { sink ->
                store.state(artifactId)?.let(sink::success)
            }
            if (deleted) {
                store.clearArtifact(artifactId)
                if (previousStatus == "failed") {
                    rebuildQueuedWork()
                }
            }
        }
        result.success(null)
    }

    private fun rebuildQueuedWork() {
        val queuedRequests = store.statesInOrder().mapNotNull { state ->
            if (state["status"] != "queued") return@mapNotNull null
            val artifactId = state["artifactId"] as? String ?: return@mapNotNull null
            store.request(artifactId)
        }
        WorkManager.getInstance(context).cancelUniqueWork(FIFO_WORK_NAME)
        queuedRequests.forEachIndexed { index, request ->
            enqueueWork(
                request,
                policy = if (index == 0) {
                    ExistingWorkPolicy.REPLACE
                } else {
                    ExistingWorkPolicy.APPEND
                },
            )
        }
    }

    private fun enqueueWork(
        request: StoredDownloadRequest,
        policy: ExistingWorkPolicy = ExistingWorkPolicy.APPEND_OR_REPLACE,
    ) {
        val input = Data.Builder().apply {
            request.toWorkDataMap().forEach { (key, value) ->
                when (value) {
                    is String -> putString(key, value)
                    is Int -> putInt(key, value)
                    is Long -> putLong(key, value)
                }
            }
        }.build()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val work = OneTimeWorkRequestBuilder<ProgressiveDownloadWorker>()
            .setInputData(input)
            .setConstraints(constraints)
            .addTag(ALL_DOWNLOADS_TAG)
            .addTag("$ARTIFACT_TAG_PREFIX${request.artifactId}")
            .build()

        // WorkManager persists this FIFO chain across process restarts.
        // Source: https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/manage-work
        WorkManager.getInstance(context).enqueueUniqueWork(
            FIFO_WORK_NAME,
            policy,
            work,
        )
    }

    private fun validateSource(source: String) {
        val uri = Uri.parse(source)
        require(uri.scheme.equals("https", ignoreCase = true) && !uri.host.isNullOrBlank()) {
            "Source must be HTTPS."
        }
        require(uri.userInfo.isNullOrBlank()) { "Source must not embed credentials." }
    }

    private fun validateArtifactId(artifactId: String) {
        require(SAFE_ARTIFACT_ID.matches(artifactId)) {
            "artifactId must be a safe 1-128 character identifier."
        }
    }

    private fun validateDestination(destinationPath: String) {
        val destination = File(destinationPath).canonicalFile
        val sandbox = context.dataDir.canonicalFile
        require(
            destination.path == sandbox.path ||
                destination.path.startsWith("${sandbox.path}${File.separator}"),
        ) {
            "Destination must be inside the application sandbox."
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        lastEmittedStates = emptyMap()
        handler.removeCallbacks(eventPoller)
        handler.post(eventPoller)
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        handler.removeCallbacks(eventPoller)
        lastEmittedStates = emptyMap()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onCancel(null)
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    companion object {
        private const val METHOD_CHANNEL = "dev.airo.platform_downloads/methods"
        private const val EVENT_CHANNEL = "dev.airo.platform_downloads/events"
        private const val FIFO_WORK_NAME = "airo-platform-downloads-v1-fifo"
        private const val ALL_DOWNLOADS_TAG = "airo-platform-downloads-v1"
        private const val ARTIFACT_TAG_PREFIX = "airo-platform-download:"
        private const val EVENT_POLL_MILLIS = 300L
        private val SAFE_ARTIFACT_ID = Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
        private val ACTIVE_STATUSES = setOf("queued", "downloading", "paused", "verifying")
        private val PAUSABLE_STATUSES = setOf("queued", "downloading", "verifying")
    }
}

private fun MethodCall.requiredString(name: String): String {
    val value = argument<String>(name)?.trim()
    require(!value.isNullOrEmpty()) { "$name is required." }
    if (name == "artifactId") {
        require(Regex("^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$").matches(value)) {
            "artifactId must be a safe 1-128 character identifier."
        }
    }
    return value
}
