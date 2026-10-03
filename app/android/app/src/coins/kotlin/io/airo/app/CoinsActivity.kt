package io.airo.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

// A focused host for Airo Coins. FlutterFragmentActivity is required by
// local_auth's Android BiometricPrompt integration.
class CoinsActivity : FlutterFragmentActivity() {
    private var nfcCapturePlugin: CoinsNfcCapturePlugin? = null

    // Android 15 (targetSdk 35) enforces edge-to-edge by default; calling this
    // explicitly (rather than relying on the enforcement fallback) is what
    // Play Console's pre-launch report checks for.
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        nfcCapturePlugin?.onLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        nfcCapturePlugin?.onLaunchIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcCapturePlugin = CoinsNfcCapturePlugin().also {
            flutterEngine.plugins.add(it)
        }
        nfcCapturePlugin?.onLaunchIntent(intent)
    }
}
