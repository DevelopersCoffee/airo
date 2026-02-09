// Stub implementation for patrol plugin
// This is needed because Flutter registers dev_dependencies plugins in GeneratedPluginRegistrant
// but the native code isn't available in release builds
package pl.leancode.patrol;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Stub plugin for patrol.
 * This plugin does nothing - it's just a placeholder to satisfy the GeneratedPluginRegistrant
 * when building release APKs.
 */
public class PatrolPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        // No-op for release builds
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        // No-op for release builds
    }
}

