package io.airo.app

import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.os.Debug
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.FutureTask

class AiroMediaAssetAnalyzerPlugin(private val activity: MainActivity) {
    companion object {
        const val CHANNEL_NAME = "com.airo.media_asset_analyzer"
    }

    private val executor = Executors.newSingleThreadExecutor()
    private val analysisJobs = ConcurrentHashMap<String, FutureTask<Unit>>()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL_NAME).setMethodCallHandler { call, result ->
            when (call.method) {
                "analyze" -> {
                    val arguments = call.arguments as? Map<*, *>
                    val request = MediaAssetAnalysisRequest.from(arguments)
                    if (request == null) {
                        result.error(
                            "invalid_arguments",
                            "Media asset analyzer requires assetId and filePath.",
                            null,
                        )
                        return@setMethodCallHandler
                    }
                    lateinit var task: FutureTask<Unit>
                    task = FutureTask {
                        try {
                            val payload = analyze(request)
                            activity.runOnUiThread {
                                result.success(payload)
                            }
                        } finally {
                            analysisJobs.remove(request.analysisId, task)
                        }
                    }
                    analysisJobs[request.analysisId] = task
                    executor.execute(task)
                }
                "cancel" -> {
                    val analysisId = call.argument<String>("analysisId")
                    analysisId?.let { analysisJobs.remove(it)?.cancel(true) }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun analyze(request: MediaAssetAnalysisRequest): Map<String, Any?> {
        val startedAt = System.currentTimeMillis()
        val startingMemoryBytes = residentMemoryBytes()
        if (Thread.currentThread().isInterrupted) {
            return cancelledPayload(startedAt, startingMemoryBytes, didUseMetadataProbe = false)
        }
        val warnings = linkedSetOf<String>()
        val fileSizeBytes = request.fileSizeBytesHint ?: runCatching {
            File(request.filePath).length()
        }.getOrNull()
        if (fileSizeBytes == null) {
            warnings.add("file_size_unavailable")
        }

        var durationMs: Long? = null
        var overallBitrate: Int? = null
        val videoTracks = mutableListOf<Map<String, Any?>>()
        val audioTracks = mutableListOf<Map<String, Any?>>()
        val subtitleTracks = mutableListOf<Map<String, Any?>>()

        var retriever: MediaMetadataRetriever? = null
        var extractor: MediaExtractor? = null
        try {
            retriever = MediaMetadataRetriever()
            retriever.setDataSource(request.filePath)
            durationMs = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION,
            )?.toLongOrNull()
            overallBitrate = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_BITRATE,
            )?.toIntOrNull()

            extractor = MediaExtractor()
            extractor.setDataSource(request.filePath)
            for (index in 0 until extractor.trackCount) {
                if (Thread.currentThread().isInterrupted) {
                    return cancelledPayload(startedAt, startingMemoryBytes, didUseMetadataProbe = true)
                }
                val format = extractor.getTrackFormat(index)
                val mimeType = format.getString(MediaFormat.KEY_MIME).orEmpty()
                when {
                    mimeType.startsWith("video/") -> {
                        videoTracks.add(
                            mapOf(
                                "id" to "video-$index",
                                "codec" to videoCodecForMimeType(mimeType),
                                "width" to format.getIntegerOrNull(MediaFormat.KEY_WIDTH),
                                "height" to format.getIntegerOrNull(MediaFormat.KEY_HEIGHT),
                                "bitrate" to format.getIntegerOrNull(MediaFormat.KEY_BIT_RATE),
                                "dynamicRange" to dynamicRangeFor(mimeType, format),
                                "confidence" to "exact",
                            ),
                        )
                    }
                    mimeType.startsWith("audio/") -> {
                        audioTracks.add(
                            mapOf(
                                "id" to "audio-$index",
                                "codec" to audioCodecForMimeType(mimeType),
                                "language" to format.getString(MediaFormat.KEY_LANGUAGE),
                                "label" to null,
                                "channelCount" to format.getIntegerOrNull(MediaFormat.KEY_CHANNEL_COUNT),
                                "isDefault" to (format.getIntegerOrNull(MediaFormat.KEY_IS_DEFAULT) == 1),
                                "isCommentary" to false,
                                "confidence" to "exact",
                            ),
                        )
                    }
                    mimeType.startsWith("text/") ||
                        mimeType.startsWith("application/") -> {
                        subtitleTracks.add(
                            mapOf(
                                "id" to "subtitle-$index",
                                "format" to subtitleFormatForMimeType(mimeType),
                                "language" to format.getString(MediaFormat.KEY_LANGUAGE),
                                "label" to null,
                                "isDefault" to (format.getIntegerOrNull(MediaFormat.KEY_IS_DEFAULT) == 1),
                                "isForced" to (format.getIntegerOrNull(MediaFormat.KEY_IS_FORCED_SUBTITLE) == 1),
                                "isCommentary" to false,
                                "confidence" to "exact",
                            ),
                        )
                    }
                }
            }
        } catch (_: Exception) {
            warnings.add("metadata_probe_failed")
            return mapOf(
                "status" to "inspection_failed",
                "failureReason" to "metadata_probe_failed",
                "profile" to mapOf(
                    "schemaVersion" to "1.0.0",
                    "assetId" to request.assetId,
                    "container" to request.containerStableId(),
                    "durationMs" to durationMs,
                    "fileSizeBytes" to fileSizeBytes,
                    "overallBitrate" to overallBitrate,
                    "videoTracks" to emptyList<Map<String, Any?>>(),
                    "audioTracks" to emptyList<Map<String, Any?>>(),
                    "subtitleTracks" to emptyList<Map<String, Any?>>(),
                    "warnings" to warnings.toList(),
                ),
                "diagnostics" to mapOf(
                    "elapsedMs" to (System.currentTimeMillis() - startedAt),
                    "didUseMetadataProbe" to true,
                    "fileSizeBytes" to fileSizeBytes,
                    "estimatedBytesRead" to null,
                    "peakMemoryBytes" to maxOf(startingMemoryBytes, residentMemoryBytes()),
                ),
            )
        } finally {
            runCatching { retriever?.release() }
            runCatching { extractor?.release() }
        }

        if (Thread.currentThread().isInterrupted) {
            return cancelledPayload(startedAt, startingMemoryBytes, didUseMetadataProbe = true)
        }
        if (durationMs == null || durationMs <= 0) {
            warnings.add("duration_unavailable")
            durationMs = null
        }
        if (overallBitrate == null && durationMs != null && fileSizeBytes != null && durationMs > 0) {
            overallBitrate = (((fileSizeBytes * 8.0) / (durationMs / 1000.0))).toInt()
            warnings.add("overall_bitrate_estimated")
        } else if (overallBitrate == null) {
            warnings.add("overall_bitrate_unavailable")
        }
        if (videoTracks.none { (it["codec"] as? String) != "unknown" }) {
            warnings.add("video_codec_unavailable")
        }
        if (audioTracks.isEmpty()) {
            warnings.add("audio_tracks_unavailable")
        }
        if (subtitleTracks.isEmpty()) {
            warnings.add("subtitle_tracks_unavailable")
        }
        if (videoTracks.none { (it["dynamicRange"] as? String) != "unknown" }) {
            warnings.add("hdr_unavailable")
        }

        return mapOf(
            "status" to "complete",
            "profile" to mapOf(
                "schemaVersion" to "1.0.0",
                "assetId" to request.assetId,
                "container" to request.containerStableId(),
                "durationMs" to durationMs,
                "fileSizeBytes" to fileSizeBytes,
                "overallBitrate" to overallBitrate,
                "videoTracks" to videoTracks,
                "audioTracks" to audioTracks,
                "subtitleTracks" to subtitleTracks,
                "warnings" to warnings.toList(),
            ),
            "diagnostics" to mapOf(
                "elapsedMs" to (System.currentTimeMillis() - startedAt),
                "didUseMetadataProbe" to true,
                "fileSizeBytes" to fileSizeBytes,
                "estimatedBytesRead" to null,
                "peakMemoryBytes" to maxOf(startingMemoryBytes, residentMemoryBytes()),
            ),
        )
    }

    private fun cancelledPayload(
        startedAt: Long,
        startingMemoryBytes: Long,
        didUseMetadataProbe: Boolean,
    ): Map<String, Any?> {
        return mapOf(
            "status" to "cancelled",
            "diagnostics" to mapOf(
                "elapsedMs" to (System.currentTimeMillis() - startedAt),
                "didUseMetadataProbe" to didUseMetadataProbe,
                "fileSizeBytes" to null,
                "estimatedBytesRead" to null,
                "peakMemoryBytes" to maxOf(startingMemoryBytes, residentMemoryBytes()),
            ),
        )
    }

    private fun residentMemoryBytes(): Long = Debug.getPss().toLong() * 1024L

    private fun videoCodecForMimeType(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "video/avc" -> "h264"
            "video/hevc" -> "hevc"
            "video/dolby-vision" -> "hevc"
            "video/av01" -> "av1"
            "video/x-vnd.on2.vp9" -> "vp9"
            else -> "unknown"
        }
    }

    private fun audioCodecForMimeType(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "audio/mp4a-latm", "audio/aac" -> "aac"
            "audio/ac3" -> "ac3"
            "audio/eac3", "audio/eac3-joc" -> "eac3"
            "audio/vnd.dts", "audio/vnd.dts.hd" -> "dts"
            "audio/true-hd" -> "truehd"
            "audio/opus" -> "opus"
            "audio/mpeg" -> "mp3"
            else -> "unknown"
        }
    }

    private fun subtitleFormatForMimeType(mimeType: String): String {
        return when (mimeType.lowercase()) {
            "application/x-subrip", "text/srt" -> "srt"
            "text/x-ssa", "text/x-ass", "application/x-ass" -> "ass"
            "application/pgs" -> "pgs"
            "application/vobsub" -> "vobsub"
            "application/dvbsubs" -> "dvb"
            else -> "unknown"
        }
    }

    private fun dynamicRangeFor(mimeType: String, format: MediaFormat): String {
        if (mimeType.equals("video/dolby-vision", ignoreCase = true)) {
            return "dolby_vision"
        }
        val colorTransfer = format.getIntegerOrNull(MediaFormat.KEY_COLOR_TRANSFER)
        return when (colorTransfer) {
            MediaFormat.COLOR_TRANSFER_ST2084 -> "hdr10"
            MediaFormat.COLOR_TRANSFER_HLG -> "hlg"
            else -> "unknown"
        }
    }
}

private data class MediaAssetAnalysisRequest(
    val analysisId: String,
    val assetId: String,
    val filePath: String,
    val fileName: String?,
    val fileSizeBytesHint: Long?,
    val mimeTypeHint: String?,
) {
    companion object {
        fun from(arguments: Map<*, *>?): MediaAssetAnalysisRequest? {
            if (arguments == null) return null
            val analysisId = arguments["analysisId"] as? String ?: return null
            val assetId = arguments["assetId"] as? String ?: return null
            val filePath = arguments["filePath"] as? String ?: return null
            return MediaAssetAnalysisRequest(
                analysisId = analysisId,
                assetId = assetId,
                filePath = filePath,
                fileName = arguments["fileName"] as? String,
                fileSizeBytesHint = (arguments["fileSizeBytesHint"] as? Number)?.toLong(),
                mimeTypeHint = arguments["mimeTypeHint"] as? String,
            )
        }
    }

    fun containerStableId(): String {
        val mimeType = mimeTypeHint?.lowercase().orEmpty()
        if ("matroska" in mimeType || "x-mkv" in mimeType) return "mkv"
        if ("webm" in mimeType) return "webm"
        if ("mp4" in mimeType) return "mp4"
        if ("quicktime" in mimeType) return "mov"
        if ("mpegts" in mimeType || "mp2t" in mimeType) return "ts"
        val extension = fileName?.substringAfterLast('.', "")?.lowercase().orEmpty()
        return when (extension) {
            "mp4" -> "mp4"
            "m4v" -> "m4v"
            "mkv" -> "mkv"
            "webm" -> "webm"
            "avi" -> "avi"
            "mov" -> "mov"
            "ts" -> "ts"
            "m2ts" -> "m2ts"
            "flv" -> "flv"
            "wmv" -> "wmv"
            "vob" -> "vob"
            else -> "unknown"
        }
    }
}

private fun MediaFormat.getIntegerOrNull(key: String): Int? {
    return if (containsKey(key)) getInteger(key) else null
}
