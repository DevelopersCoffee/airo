package io.airo.app

import android.content.Intent
import android.net.Uri
import android.nfc.NdefMessage
import android.nfc.NfcAdapter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Surfaces NFC / VIEW intents that target the Coins quick-capture URI to Dart.
 *
 * CI and local testing without hardware:
 * `adb shell am start -a android.intent.action.VIEW -d "airo://coins/quick-capture"`
 */
class CoinsNfcCapturePlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var pendingCapture: Boolean = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPendingCapture" -> {
                result.success(pendingCapture)
            }
            "consumePendingCapture" -> {
                val wasPending = pendingCapture
                pendingCapture = false
                result.success(wasPending)
            }
            "debugSimulateCapture" -> {
                if (BuildConfig.DEBUG) {
                    pendingCapture = true
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
            else -> result.notImplemented()
        }
    }

    fun onLaunchIntent(intent: Intent?) {
        if (matchesCaptureIntent(intent)) {
            pendingCapture = true
        }
    }

    companion object {
        const val CHANNEL_NAME = "io.airo.app/coins_nfc_capture"

        private const val SCHEME_AIRO = "airo"
        private const val HOST_COINS = "coins"
        private const val PATH_CAPTURE = "/quick-capture"
        private const val HTTPS_HOST = "developerscoffee.github.io"
        private const val HTTPS_PATH = "/airo/coins/quick-capture"

        fun matchesCaptureIntent(intent: Intent?): Boolean {
            if (intent == null) return false
            when (intent.action) {
                NfcAdapter.ACTION_NDEF_DISCOVERED,
                NfcAdapter.ACTION_TECH_DISCOVERED,
                Intent.ACTION_VIEW -> {
                    val uri = extractUri(intent) ?: return false
                    return matchesCaptureUri(uri)
                }
            }
            return false
        }

        private fun extractUri(intent: Intent): Uri? {
            intent.data?.let { return it }
            val rawMessages = intent.getParcelableArrayExtra(NfcAdapter.EXTRA_NDEF_MESSAGES)
            if (rawMessages != null) {
                for (raw in rawMessages) {
                    val message = raw as? NdefMessage ?: continue
                    for (record in message.records) {
                        val uri = record.toUri()
                        if (uri != null) return uri
                    }
                }
            }
            return null
        }

        fun matchesCaptureUri(uri: Uri): Boolean {
            if (SCHEME_AIRO == uri.scheme && HOST_COINS == uri.host) {
                val path = uri.path ?: return false
                return path == PATH_CAPTURE || path == "$PATH_CAPTURE/"
            }
            if ("https" == uri.scheme && HTTPS_HOST == uri.host) {
                val path = uri.path ?: return false
                return path == HTTPS_PATH || path == "$HTTPS_PATH/"
            }
            return false
        }
    }
}
