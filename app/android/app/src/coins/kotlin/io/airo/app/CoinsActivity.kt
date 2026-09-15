package io.airo.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// A focused host for Airo Coins. FlutterFragmentActivity is required by
// local_auth's Android BiometricPrompt integration.
class CoinsActivity : FlutterFragmentActivity() {
    // Android 15 (targetSdk 35) enforces edge-to-edge by default; calling this
    // explicitly (rather than relying on the enforcement fallback) is what
    // Play Console's pre-launch report checks for.
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
