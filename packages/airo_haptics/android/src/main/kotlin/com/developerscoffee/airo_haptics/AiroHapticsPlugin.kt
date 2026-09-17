package com.developerscoffee.airo_haptics

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class AiroHapticsPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var context: Context? = null
  private var vibrator: Vibrator? = null

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    context = flutterPluginBinding.applicationContext
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.developerscoffee.airo/airo_haptics")
    channel.setMethodCallHandler(this)

    vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      val vibratorManager = context?.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
      vibratorManager?.defaultVibrator
    } else {
      @Suppress("DEPRECATION")
      context?.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    val currentVibrator = vibrator
    if (currentVibrator == null || !currentVibrator.hasVibrator()) {
      when (call.method) {
        "getCapabilities" -> result.success(mapOf(
          "supported" to false,
          "basic" to false,
          "advanced" to false,
          "customPatterns" to false,
          "continuous" to false,
          "variableIntensity" to false,
          "variableSharpness" to false,
          "platform" to "android",
          "backend" to "none"
        ))
        else -> result.success(null)
      }
      return
    }

    when (call.method) {
      "getCapabilities" -> {
        val hasAmplitude = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) currentVibrator.hasAmplitudeControl() else false
        result.success(mapOf(
          "supported" to true,
          "basic" to true,
          "advanced" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R),
          "customPatterns" to true,
          "continuous" to true,
          "variableIntensity" to hasAmplitude,
          "variableSharpness" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
          "platform" to "android",
          "backend" to "Android Vibrator/VibrationEffect"
        ))
      }
      "performFeedback" -> {
        val type = call.argument<String>("type") ?: "selection"
        vibrateSemantic(currentVibrator, type)
        result.success(null)
      }
      "performImpact" -> {
        val impact = call.argument<String>("impact") ?: "medium"
        val intensity = call.argument<Double>("intensity") ?: 0.6
        vibrateImpact(currentVibrator, impact, intensity)
        result.success(null)
      }
      "playPattern" -> {
        val patternMap = call.argument<Map<String, Any>>("pattern")
        if (patternMap != null) {
          playPatternMap(currentVibrator, patternMap)
        } else {
          vibrateLegacy(currentVibrator, 50)
        }
        result.success(null)
      }
      "updatePattern" -> {
        val intensity = call.argument<Double>("intensity") ?: 1.0
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && currentVibrator.hasAmplitudeControl()) {
          val amplitude = (intensity * 255).toInt().coerceIn(1, 255)
          currentVibrator.vibrate(VibrationEffect.createOneShot(50L, amplitude))
        }
        result.success(null)
      }
      "stopAll", "stopPattern" -> {
        currentVibrator.cancel()
        result.success(null)
      }
      "updateSettings" -> {
        result.success(null)
      }
      "getDiagnostics" -> {
        result.success(mapOf(
          "totalTriggers" to 1,
          "playedCount" to 1,
          "droppedCount" to 0,
          "activeBackend" to "Android Vibrator",
          "lastTriggeredType" to "kotlin_native"
        ))
      }
      else -> result.notImplemented()
    }
  }

  private fun vibrateSemantic(vib: Vibrator, type: String) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val effectId = when (type) {
        "selection", "focus", "press" -> VibrationEffect.EFFECT_TICK
        "impact", "confirm", "toggleOn", "toggleOff" -> VibrationEffect.EFFECT_CLICK
        "heavy", "error", "failure", "delete", "reject" -> VibrationEffect.EFFECT_HEAVY_CLICK
        "doubleClick" -> VibrationEffect.EFFECT_DOUBLE_CLICK
        else -> VibrationEffect.EFFECT_CLICK
      }
      try {
        vib.vibrate(VibrationEffect.createPredefined(effectId))
        return
      } catch (_: Exception) {}
    }

    val duration = when (type) {
      "selection", "focus" -> 15L
      "light", "soft" -> 25L
      "medium", "confirm" -> 40L
      "heavy", "error", "failure", "delete" -> 70L
      else -> 30L
    }
    vibrateLegacy(vib, duration)
  }

  private fun vibrateImpact(vib: Vibrator, impact: String, intensity: Double) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vib.hasAmplitudeControl()) {
      val amplitude = (intensity * 255).toInt().coerceIn(1, 255)
      val duration = when (impact) {
        "light", "soft" -> 20L
        "medium" -> 40L
        "heavy", "rigid" -> 75L
        else -> 35L
      }
      vib.vibrate(VibrationEffect.createOneShot(duration, amplitude))
    } else {
      val duration = (intensity * 60).toLong().coerceAtLeast(15L)
      vibrateLegacy(vib, duration)
    }
  }

  private fun playPatternMap(vib: Vibrator, pattern: Map<String, Any>) {
    val events = pattern["events"] as? List<*> ?: return
    if (events.isEmpty()) return

    val timings = mutableListOf<Long>()
    val amplitudes = mutableListOf<Int>()

    timings.add(0L)
    amplitudes.add(0)

    for (item in events) {
      if (item is Map<*, *>) {
        val delayMs = (item["delayMs"] as? Number)?.toLong() ?: 0L
        val durationMs = (item["durationMs"] as? Number)?.toLong() ?: 30L
        val intensity = (item["intensity"] as? Number)?.toDouble() ?: 1.0

        if (delayMs > 0) {
          timings.add(delayMs)
          amplitudes.add(0)
        }

        timings.add(if (durationMs > 0) durationMs else 25L)
        amplitudes.add((intensity * 255).toInt().coerceIn(1, 255))
      }
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && vib.hasAmplitudeControl()) {
      val timingArray = timings.toLongArray()
      val amplitudeArray = amplitudes.toIntArray()
      vib.vibrate(VibrationEffect.createWaveform(timingArray, amplitudeArray, -1))
    } else {
      vibrateLegacy(vib, 100)
    }
  }

  private fun vibrateLegacy(vib: Vibrator, duration: Long) {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      vib.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
    } else {
      @Suppress("DEPRECATION")
      vib.vibrate(duration)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    context = null
    vibrator = null
  }
}
