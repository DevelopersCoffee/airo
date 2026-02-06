package com.airo.superapp

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import com.google.mlkit.genai.common.DownloadCallback
import com.google.mlkit.genai.common.DownloadStatus
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.GenerateContentRequest
import com.google.mlkit.genai.prompt.GenerateContentResponse
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/**
 * Gemini Nano Plugin for Flutter
 * Provides on-device AI inference using ML Kit GenAI Prompt API on Pixel 9+ devices
 *
 * Based on: https://developers.google.com/ml-kit/genai/prompt/android/get-started
 */
class GeminiNanoPlugin(private val context: Context) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "GeminiNanoPlugin"
        private const val CHANNEL_NAME = "com.airo.gemini_nano"
        private const val EVENT_CHANNEL_NAME = "com.airo.gemini_nano/stream"

        fun registerWith(flutterEngine: FlutterEngine) {
            val context = flutterEngine.dartExecutor.binaryMessenger.let { messenger ->
                flutterEngine.dartExecutor.binaryMessenger
            }

            val plugin = GeminiNanoPlugin(
                flutterEngine.dartExecutor.binaryMessenger.let {
                    // Get context from FlutterEngine
                    null as? Context ?: throw IllegalStateException("Context not available")
                }
            )

            val methodChannel = MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                CHANNEL_NAME
            )
            methodChannel.setMethodCallHandler(plugin)

            val eventChannel = EventChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                EVENT_CHANNEL_NAME
            )
            eventChannel.setStreamHandler(plugin.streamHandler)
        }
    }

    private var isInitialized = false
    private var generativeModel: GenerativeModel? = null
    private val coroutineScope = CoroutineScope(Dispatchers.Main)

    // Stream handler for streaming responses
    private val streamHandler = object : EventChannel.StreamHandler {
        private var eventSink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
            eventSink = events
        }

        override fun onCancel(arguments: Any?) {
            eventSink = null
        }

        fun sendChunk(chunk: String) {
            eventSink?.success(chunk)
        }

        fun sendError(error: String) {
            eventSink?.error("GENERATION_ERROR", error, null)
        }

        fun endStream() {
            eventSink?.endOfStream()
        }
    }

    // Public method to get stream handler
    fun getStreamHandler(): EventChannel.StreamHandler = streamHandler
    
    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> checkAvailability(result)
            "initialize" -> initialize(call, result)
            "generateContent" -> generateContent(call, result)
            "generateContentStream" -> generateContentStream(call, result)
            "getDeviceInfo" -> getDeviceInfo(result)
            "getMemoryInfo" -> getMemoryInfo(result)
            "getCapabilities" -> getCapabilities(result)
            else -> result.notImplemented()
        }
    }
    
    /**
     * Check if Gemini Nano is available on this device using ML Kit GenAI API
     * Uses FeatureStatus to check model availability
     */
    private fun checkAvailability(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                // Initialize generative model if not already done
                if (generativeModel == null) {
                    generativeModel = Generation.getClient()
                }

                // Check feature status - returns @FeatureStatus int directly
                val status: Int = generativeModel!!.checkStatus()

                when (status) {
                    FeatureStatus.AVAILABLE -> {
                        Log.d(TAG, "Gemini Nano is AVAILABLE")
                        result.success(true)
                    }
                    FeatureStatus.DOWNLOADABLE -> {
                        Log.d(TAG, "Gemini Nano is DOWNLOADABLE - needs download")
                        result.success(true) // Available but needs download
                    }
                    FeatureStatus.DOWNLOADING -> {
                        Log.d(TAG, "Gemini Nano is currently DOWNLOADING")
                        result.success(true) // In progress
                    }
                    FeatureStatus.UNAVAILABLE -> {
                        Log.d(TAG, "Gemini Nano is UNAVAILABLE on this device")
                        result.success(false)
                    }
                    else -> {
                        Log.d(TAG, "Unknown Gemini Nano status: $status")
                        result.success(false)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error checking availability: ${e.message}", e)
                result.error("AVAILABILITY_CHECK_FAILED", e.message, null)
            }
        }
    }

    /**
     * Initialize Gemini Nano with configuration
     * Downloads the model if needed
     */
    private fun initialize(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                // Initialize generative model if not already done
                if (generativeModel == null) {
                    generativeModel = Generation.getClient()
                }

                // Check current status - returns @FeatureStatus int directly
                val status: Int = generativeModel!!.checkStatus()
                Log.d(TAG, "Initialize: Current status = $status")

                when (status) {
                    FeatureStatus.AVAILABLE -> {
                        Log.d(TAG, "Gemini Nano already available")
                        isInitialized = true
                        result.success(true)
                    }
                    FeatureStatus.DOWNLOADABLE -> {
                        Log.d(TAG, "Starting Gemini Nano download...")
                        // Download the model using Flow-based API
                        var downloadCompleted = false
                        generativeModel!!.download()
                            .catch { e ->
                                Log.e(TAG, "Download failed: ${e.message}", e)
                                result.error("DOWNLOAD_FAILED", e.message, null)
                            }
                            .collect { downloadStatus ->
                                when (downloadStatus) {
                                    is DownloadStatus.DownloadStarted -> {
                                        Log.d(TAG, "Download started...")
                                    }
                                    is DownloadStatus.DownloadProgress -> {
                                        Log.d(TAG, "Download progress: ${downloadStatus.totalBytesDownloaded} bytes downloaded")
                                    }
                                    DownloadStatus.DownloadCompleted -> {
                                        Log.d(TAG, "Gemini Nano download complete")
                                        isInitialized = true
                                        downloadCompleted = true
                                    }
                                    is DownloadStatus.DownloadFailed -> {
                                        Log.e(TAG, "Download failed: ${downloadStatus.e.message}")
                                        result.error("DOWNLOAD_FAILED", downloadStatus.e.message, null)
                                    }
                                }
                            }
                        if (downloadCompleted) {
                            result.success(true)
                        }
                    }
                    FeatureStatus.DOWNLOADING -> {
                        Log.d(TAG, "Gemini Nano is already downloading, waiting...")
                        // Wait for download to complete by polling
                        pollForAvailability(result)
                    }
                    FeatureStatus.UNAVAILABLE -> {
                        Log.e(TAG, "Gemini Nano is not available on this device")
                        result.error("UNAVAILABLE", "Gemini Nano not available on this device", null)
                    }
                    else -> {
                        result.error("UNKNOWN_STATUS", "Unknown status: $status", null)
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Initialization failed: ${e.message}", e)
                result.error("INITIALIZATION_FAILED", e.message, null)
            }
        }
    }

    /**
     * Poll for model availability during download
     */
    private fun pollForAvailability(result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                var attempts = 0
                val maxAttempts = 60 // Max 60 seconds

                while (attempts < maxAttempts) {
                    val status: Int = generativeModel!!.checkStatus()

                    if (status == FeatureStatus.AVAILABLE) {
                        Log.d(TAG, "Model now available after polling")
                        isInitialized = true
                        result.success(true)
                        return@launch
                    } else if (status == FeatureStatus.UNAVAILABLE) {
                        Log.e(TAG, "Model became unavailable during polling")
                        result.error("UNAVAILABLE", "Model became unavailable", null)
                        return@launch
                    }

                    delay(1000) // Wait 1 second (proper coroutine suspension)
                    attempts++
                }

                result.error("TIMEOUT", "Timeout waiting for model download", null)
            } catch (e: Exception) {
                Log.e(TAG, "Error polling for availability: ${e.message}", e)
                result.error("POLLING_FAILED", e.message, null)
            }
        }
    }

    /**
     * Ensure model is initialized before use
     */
    private suspend fun ensureInitialized(): Boolean {
        if (isInitialized && generativeModel != null) return true

        try {
            if (generativeModel == null) {
                generativeModel = Generation.getClient()
            }

            val status: Int = generativeModel!!.checkStatus()
            if (status == FeatureStatus.AVAILABLE) {
                isInitialized = true
                return true
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error ensuring initialization: ${e.message}", e)
        }
        return false
    }

    /**
     * Generate content using Gemini Nano (non-streaming)
     */
    private fun generateContent(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                // Ensure model is initialized
                if (!ensureInitialized()) {
                    result.error("NOT_INITIALIZED", "Gemini Nano not initialized", null)
                    return@launch
                }

                val prompt = call.argument<String>("prompt")
                    ?: throw IllegalArgumentException("Prompt is required")

                Log.d(TAG, "Generating content for prompt: ${prompt.take(50)}...")

                // Build the request
                val request = GenerateContentRequest.Builder(TextPart(prompt)).build()

                // Generate content using ML Kit - generateContent is a suspend function
                val response = generativeModel!!.generateContent(request)

                // Extract text from response - candidates list, first candidate, get text
                val text = response.candidates.firstOrNull()?.text ?: ""
                Log.d(TAG, "Generated response: ${text.take(100)}...")

                result.success(text)
            } catch (e: Exception) {
                Log.e(TAG, "Generation failed: ${e.message}", e)
                result.error("GENERATION_FAILED", e.message, null)
            }
        }
    }

    /**
     * Generate content with streaming response using ML Kit GenAI
     */
    private fun generateContentStream(call: MethodCall, result: MethodChannel.Result) {
        coroutineScope.launch {
            try {
                // Ensure model is initialized
                if (!ensureInitialized()) {
                    streamHandler.sendError("Gemini Nano not initialized")
                    result.error("NOT_INITIALIZED", "Gemini Nano not initialized", null)
                    return@launch
                }

                val prompt = call.argument<String>("prompt")
                    ?: throw IllegalArgumentException("Prompt is required")

                Log.d(TAG, "Starting streaming generation for: ${prompt.take(50)}...")

                // Build the request
                val request = GenerateContentRequest.Builder(TextPart(prompt)).build()

                var fullResponse = ""

                // Use streaming API
                generativeModel!!.generateContentStream(request)
                    .catch { e ->
                        Log.e(TAG, "Streaming error: ${e.message}", e)
                        withContext(Dispatchers.Main) {
                            streamHandler.sendError(e.message ?: "Unknown error")
                        }
                    }
                    .collect { chunk ->
                        val chunkText = chunk.candidates.firstOrNull()?.text ?: ""
                        fullResponse += chunkText

                        // Send accumulated response to Flutter
                        withContext(Dispatchers.Main) {
                            streamHandler.sendChunk(fullResponse)
                        }
                    }

                Log.d(TAG, "Streaming complete. Full response: ${fullResponse.take(100)}...")

                // End stream
                withContext(Dispatchers.Main) {
                    streamHandler.endStream()
                }
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Streaming failed: ${e.message}", e)
                withContext(Dispatchers.Main) {
                    streamHandler.sendError(e.message ?: "Unknown error")
                }
                result.error("STREAMING_FAILED", e.message, null)
            }
        }
    }
    
    /**
     * Get device information
     */
    private fun getDeviceInfo(result: MethodChannel.Result) {
        val deviceInfo = mapOf(
            "manufacturer" to Build.MANUFACTURER,
            "model" to Build.MODEL,
            "brand" to Build.BRAND,
            "device" to Build.DEVICE,
            "product" to Build.PRODUCT,
            "release" to Build.VERSION.RELEASE,
            "sdkVersion" to Build.VERSION.SDK_INT,
            "isPixel" to isPixel9Device(),
            "supportsGeminiNano" to (isPixel9Device() && Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
        )
        result.success(deviceInfo)
    }
    
    /**
     * Get device memory information
     * Uses ActivityManager to query total and available RAM
     */
    private fun getMemoryInfo(result: MethodChannel.Result) {
        try {
            val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val memoryInfo = ActivityManager.MemoryInfo()
            activityManager.getMemoryInfo(memoryInfo)

            val memoryData = mapOf(
                "totalBytes" to memoryInfo.totalMem,
                "availableBytes" to memoryInfo.availMem,
                "threshold" to memoryInfo.threshold,
                "lowMemory" to memoryInfo.lowMemory
            )
            result.success(memoryData)
        } catch (e: Exception) {
            result.error("MEMORY_INFO_FAILED", e.message, null)
        }
    }

    /**
     * Get Gemini Nano capabilities
     */
    private fun getCapabilities(result: MethodChannel.Result) {
        val capabilities = mapOf(
            "summarization" to true,
            "imageDescription" to true,
            "proofreading" to true,
            "rewriting" to true,
            "chat" to true,
            "maxTokens" to 2048,
            "supportedLanguages" to listOf("en", "es", "fr", "de", "it", "pt", "ja", "ko", "zh")
        )
        result.success(capabilities)
    }
    
    // Helper methods

    private fun isPixel9Device(): Boolean {
        val model = Build.MODEL.lowercase()
        val device = Build.DEVICE.lowercase()

        return (Build.MANUFACTURER.equals("Google", ignoreCase = true) &&
                (model.contains("pixel 9") ||
                 device.contains("komodo") ||  // Pixel 9
                 device.contains("caiman") ||  // Pixel 9 Pro
                 device.contains("tokay") ||   // Pixel 9 Pro XL
                 device.contains("comet")))    // Pixel 9 Pro Fold
    }
}

