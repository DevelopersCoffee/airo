// Stub implementation for integration_test plugin
// This is needed because Flutter registers dev_dependencies plugins in GeneratedPluginRegistrant
// but the native code isn't available in release builds
package dev.flutter.plugins.integration_test;

import io.flutter.embedding.engine.plugins.FlutterPlugin;

/**
 * Stub plugin for integration_test.
 * This plugin does nothing - it's just a placeholder to satisfy the GeneratedPluginRegistrant
 * when building release APKs.
 */
public class IntegrationTestPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        // No-op for release builds
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        // No-op for release builds
    }
}

