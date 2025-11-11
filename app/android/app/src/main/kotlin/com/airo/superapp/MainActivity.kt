package com.airo.superapp

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val GEMINI_NANO_CHANNEL = "com.airo.gemini_nano"
    private val GEMINI_NANO_EVENT_CHANNEL = "com.airo.gemini_nano/stream"

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
    }
}

