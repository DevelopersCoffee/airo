package io.airo.app

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterFragmentActivity

// Focused host for Anya. Fragment activity keeps plugin activity results
// (file picker) on a stable activity surface.
class AnyaActivity : FlutterFragmentActivity() {
    // Android 15 (targetSdk 35) enforces edge-to-edge by default; calling this
    // explicitly (rather than relying on the enforcement fallback) is what
    // Play Console's pre-launch report checks for.
    override fun onCreate(savedInstanceState: Bundle?) {
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
