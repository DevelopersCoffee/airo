package io.airo.app

import android.Manifest
import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.ContactsContract
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.telephony.TelephonyManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Locale

// AudioServiceFragmentActivity (FlutterFragmentActivity) rather than
// AudioServiceActivity (FlutterActivity): local_auth hosts Android's
// BiometricPrompt in a Fragment, so a plain FlutterActivity makes every
// authenticate() call throw no_fragment_activity — the vault could never
// show a biometric prompt. The audio_service behaviour is identical
// between the two base classes.
class MainActivity : AudioServiceFragmentActivity() {
    private val GEMINI_NANO_CHANNEL = "com.airo.gemini_nano"
    private val GEMINI_NANO_EVENT_CHANNEL = "com.airo.gemini_nano/stream"
    private val LITERT_LM_CHANNEL = "com.airo.litert_lm"
    private val EMBEDDING_CHANNEL = "com.airo.embedding"
    private val DEVICE_INFO_CHANNEL = "com.airo/device_info"
    // Foreground-service mic-use notification for in-app meeting capture
    // (#1656 AC2). See MeetingRecordingService's doc comment for why this is
    // a plain start/stop Intent pair rather than a bound service.
    private val MEETING_RECORDING_CHANNEL = "com.airo.meeting_recording"
    private val VOICE_PERMISSION_REQUEST = 9003
    private val FLASHLIGHT_PERMISSION_REQUEST = 9004

    private var speechRecognizer: SpeechRecognizer? = null
    private var pendingVoiceResult: MethodChannel.Result? = null
    private var pendingFlashlightResult: MethodChannel.Result? = null
    private var pendingFlashlightEnabled: Boolean? = null

    private lateinit var streamingEnginePlugin: AiroStreamingEnginePlugin
    private lateinit var pictureInPicturePlugin: AiroPictureInPicturePlugin
    private lateinit var backgroundAudioPlugin: AiroBackgroundAudioPlugin
    private lateinit var phoneMediaPickerPlugin: PhoneMediaPickerPlugin
    private lateinit var mediaAssetAnalyzerPlugin: AiroMediaAssetAnalyzerPlugin
    private lateinit var localMediaPlugin: AiroLocalMediaPlugin

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Register Gemini Nano plugin
        val plugin = GeminiNanoPlugin(this)

        // Register MethodChannel for method calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEMINI_NANO_CHANNEL)
            .setMethodCallHandler(plugin)

        // Register EventChannel for streaming
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GEMINI_NANO_EVENT_CHANNEL)
            .setStreamHandler(plugin.getStreamHandler())

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LITERT_LM_CHANNEL)
            .setMethodCallHandler(LiteRtLmPlugin(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMBEDDING_CHANNEL)
            .setMethodCallHandler(EmbeddingPlugin(this))

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_INFO_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isTV" -> result.success(isTvDevice())
                    "getTvPlatform" -> result.success(getTvPlatform())
                    "getSimCountryIso" -> {
                        val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                        result.success(telephony?.simCountryIso?.takeIf { it.isNotBlank() }?.uppercase(Locale.US))
                    }
                    "openWifiSettings" -> openWifiSettings(result)
                    "setFlashlight" -> setFlashlight(call, result)
                    "composeEmail" -> composeEmail(call, result)
                    "createContact" -> createContact(call, result)
                    "openMap" -> openMap(call, result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.airo.voice_search")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAvailable" -> result.success(
                        SpeechRecognizer.isRecognitionAvailable(this)
                    )
                    "startListening" -> startVoiceListening(result)
                    "stopListening" -> stopVoiceListening(result)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEETING_RECORDING_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val title = call.argument<String>("title") ?: "Recording meeting audio"
                        val text = call.argument<String>("text")
                        val intent = MeetingRecordingService.startIntent(this, title, text)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        startService(MeetingRecordingService.stopIntent(this))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        streamingEnginePlugin = AiroStreamingEnginePlugin()
        streamingEnginePlugin.register(flutterEngine.dartExecutor.binaryMessenger)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            AiroStreamingSurfaceViewFactory.VIEW_TYPE_ID,
            AiroStreamingSurfaceViewFactory(streamingEnginePlugin::notifyPhase),
        )

        pictureInPicturePlugin = AiroPictureInPicturePlugin(this)
        pictureInPicturePlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        backgroundAudioPlugin = AiroBackgroundAudioPlugin(this)
        backgroundAudioPlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        phoneMediaPickerPlugin = PhoneMediaPickerPlugin(this)
        phoneMediaPickerPlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        mediaAssetAnalyzerPlugin = AiroMediaAssetAnalyzerPlugin(this)
        mediaAssetAnalyzerPlugin.register(flutterEngine.dartExecutor.binaryMessenger)

        localMediaPlugin = AiroLocalMediaPlugin(this)
        localMediaPlugin.register(flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        // Home press fires this while the Activity is still resumed — the only
        // safe point to enter PiP on API 26–30 (see AiroPictureInPicturePlugin).
        pictureInPicturePlugin.onUserLeaveHint()
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        pictureInPicturePlugin.notifyModeChanged(isInPictureInPictureMode)
    }

    private fun isTvDevice(): Boolean {
        val uiModeManager = getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
        return packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK_ONLY) ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv") ||
            uiModeManager?.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION
    }

    private fun getTvPlatform(): String {
        if (packageManager.hasSystemFeature("amazon.hardware.fire_tv")) {
            return "fire_tv"
        }
        if (isTvDevice()) {
            return "android_tv"
        }
        return "none"
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        when (requestCode) {
            VOICE_PERMISSION_REQUEST -> {
                val result = pendingVoiceResult
                pendingVoiceResult = null
                if (result == null) return
                if (grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                ) {
                    beginVoiceListening(result)
                } else {
                    result.success(
                        mapOf(
                            "error" to "microphone_permission_denied",
                            "message" to "Microphone permission is required for voice input."
                        )
                    )
                }
            }
            FLASHLIGHT_PERMISSION_REQUEST -> {
                val result = pendingFlashlightResult
                val enabled = pendingFlashlightEnabled
                pendingFlashlightResult = null
                pendingFlashlightEnabled = null
                if (result == null || enabled == null) return
                if (grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
                ) {
                    applyFlashlight(enabled, result)
                } else {
                    result.success(mapOf("changed" to false, "reason" to "camera_permission_denied"))
                }
            }
        }
    }

    private fun startVoiceListening(result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.success(
                mapOf(
                    "error" to "speech_unavailable",
                    "message" to "Speech recognition is unavailable on this device."
                )
            )
            return
        }
        if (pendingVoiceResult != null) {
            result.success(
                mapOf(
                    "error" to "speech_busy",
                    "message" to "A voice capture is already in progress."
                )
            )
            return
        }
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            pendingVoiceResult = result
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), VOICE_PERMISSION_REQUEST)
            return
        }
        beginVoiceListening(result)
    }

    private fun beginVoiceListening(result: MethodChannel.Result) {
        val recognizer = SpeechRecognizer.createSpeechRecognizer(this)
        speechRecognizer?.destroy()
        speechRecognizer = recognizer
        pendingVoiceResult = result
        recognizer.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) = Unit
            override fun onBeginningOfSpeech() = Unit
            override fun onRmsChanged(rmsdB: Float) = Unit
            override fun onBufferReceived(buffer: ByteArray?) = Unit
            override fun onEndOfSpeech() = Unit
            override fun onPartialResults(partialResults: Bundle?) = Unit
            override fun onEvent(eventType: Int, params: Bundle?) = Unit

            override fun onResults(results: Bundle?) {
                val text = results
                    ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()
                val confidence = results
                    ?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
                    ?.firstOrNull()
                completeVoice(
                    if (text.isNullOrBlank()) {
                        mapOf(
                            "error" to "no_speech",
                            "message" to "No speech was recognized."
                        )
                    } else {
                        mapOf(
                            "text" to text,
                            "confidence" to (confidence ?: 1.0f)
                        )
                    }
                )
            }

            override fun onError(error: Int) {
                completeVoice(
                    mapOf(
                        "error" to "speech_error_$error",
                        "message" to speechErrorMessage(error)
                    )
                )
            }
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
            // India-focused meetings often mix English, Hindi, and Marathi in
            // one take. Preference order lets the platform recognizer fall
            // through locales instead of stopping at the first mismatch.
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "en-IN")
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE,
                arrayOf("en-IN", "hi-IN", "mr-IN", "hi", "mr", "en")
            )
            // Prefer the device speech pack so Audio Scribe does not silently
            // send microphone audio to a network recognizer when an offline
            // language pack is installed. Android may still report an
            // explicit unavailable/network error when no offline pack exists.
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
        }
        try {
            recognizer.startListening(intent)
        } catch (error: Exception) {
            completeVoice(
                mapOf(
                    "error" to "speech_start_failed",
                    "message" to (error.message ?: "Speech recognition could not start.")
                )
            )
        }
    }

    private fun completeVoice(payload: Map<String, Any?>) {
        val result = pendingVoiceResult
        pendingVoiceResult = null
        speechRecognizer?.destroy()
        speechRecognizer = null
        result?.success(payload)
    }

    private fun stopVoiceListening(result: MethodChannel.Result) {
        pendingVoiceResult?.success(
            mapOf(
                "error" to "speech_cancelled",
                "message" to "Voice capture was cancelled."
            )
        )
        pendingVoiceResult = null
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        result.success(null)
    }

    private fun speechErrorMessage(error: Int): String {
        return when (error) {
            SpeechRecognizer.ERROR_AUDIO -> "Microphone audio could not be captured."
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Microphone permission is required for voice input."
            SpeechRecognizer.ERROR_NETWORK,
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Speech recognition network request timed out."
            SpeechRecognizer.ERROR_NO_MATCH -> "No speech was recognized."
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Speech recognition is busy."
            SpeechRecognizer.ERROR_SERVER -> "The speech recognition service failed."
            else -> "Speech recognition failed."
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (
            ::localMediaPlugin.isInitialized &&
            localMediaPlugin.onActivityResult(requestCode, resultCode, data)
        ) {
            return
        }
        if (
            ::phoneMediaPickerPlugin.isInitialized &&
            phoneMediaPickerPlugin.onActivityResult(requestCode, resultCode, data)
        ) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun onDestroy() {
        speechRecognizer?.cancel()
        speechRecognizer?.destroy()
        speechRecognizer = null
        pendingVoiceResult = null
        pendingFlashlightResult = null
        pendingFlashlightEnabled = null
        super.onDestroy()
    }

    private fun openWifiSettings(result: MethodChannel.Result) {
        try {
            startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
            result.success(mapOf("opened" to true))
        } catch (error: android.content.ActivityNotFoundException) {
            result.success(mapOf("opened" to false))
        }
    }

    private fun setFlashlight(call: MethodCall, result: MethodChannel.Result) {
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            pendingFlashlightResult = result
            pendingFlashlightEnabled = call.argument<Boolean>("enabled") ?: false
            requestPermissions(arrayOf(Manifest.permission.CAMERA), FLASHLIGHT_PERMISSION_REQUEST)
            return
        }
        applyFlashlight(call.argument<Boolean>("enabled") ?: false, result)
    }

    private fun applyFlashlight(enabled: Boolean, result: MethodChannel.Result) {
        try {
            val cameraManager = getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val cameraId = cameraManager.cameraIdList.firstOrNull { id ->
                cameraManager.getCameraCharacteristics(id)
                    .get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
            }
            if (cameraId == null) {
                result.success(mapOf("changed" to false, "reason" to "flash_unavailable"))
                return
            }
            cameraManager.setTorchMode(cameraId, enabled)
            result.success(mapOf("changed" to true))
        } catch (error: Exception) {
            result.success(mapOf("changed" to false, "reason" to (error.message ?: "flashlight_failed")))
        }
    }

    private fun composeEmail(call: MethodCall, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_SENDTO).apply {
                data = Uri.parse("mailto:")
                call.argument<String>("to")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(it))
                }
                call.argument<String>("subject")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(Intent.EXTRA_SUBJECT, it)
                }
                call.argument<String>("body")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(Intent.EXTRA_TEXT, it)
                }
            }
            startActivity(Intent.createChooser(intent, "Choose email app"))
            result.success(mapOf("opened" to true))
        } catch (error: Exception) {
            result.success(mapOf("opened" to false))
        }
    }

    private fun createContact(call: MethodCall, result: MethodChannel.Result) {
        try {
            val intent = Intent(Intent.ACTION_INSERT, ContactsContract.Contacts.CONTENT_URI).apply {
                call.argument<String>("name")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(ContactsContract.Intents.Insert.NAME, it)
                }
                call.argument<String>("phone")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(ContactsContract.Intents.Insert.PHONE, it)
                }
                call.argument<String>("email")?.takeIf { it.isNotBlank() }?.let {
                    putExtra(ContactsContract.Intents.Insert.EMAIL, it)
                }
            }
            startActivity(Intent.createChooser(intent, "Choose contacts app"))
            result.success(mapOf("opened" to true))
        } catch (error: Exception) {
            result.success(mapOf("opened" to false))
        }
    }

    private fun openMap(call: MethodCall, result: MethodChannel.Result) {
        try {
            val query = call.argument<String>("query")?.trim().orEmpty()
            val uri = if (query.isEmpty()) {
                Uri.parse("geo:0,0")
            } else {
                Uri.parse("geo:0,0?q=${Uri.encode(query)}")
            }
            startActivity(Intent.createChooser(Intent(Intent.ACTION_VIEW, uri), "Choose map app"))
            result.success(mapOf("opened" to true))
        } catch (error: Exception) {
            result.success(mapOf("opened" to false))
        }
    }

}
