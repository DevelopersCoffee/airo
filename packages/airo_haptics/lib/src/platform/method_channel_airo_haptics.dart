import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/haptic_capabilities.dart';
import '../models/haptic_diagnostics.dart';
import '../models/haptic_intent.dart';
import '../models/haptic_options.dart';
import '../models/haptic_pattern.dart';
import '../models/haptic_settings.dart';
import 'airo_haptics_platform.dart';

/// An implementation of [AiroHapticsPlatform] that uses method channels.
class MethodChannelAiroHaptics extends AiroHapticsPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final MethodChannel channel = const MethodChannel('com.developerscoffee.airo/airo_haptics');

  int _totalTriggers = 0;
  int _playedCount = 0;
  int _droppedCount = 0;
  String? _lastType;
  DateTime? _lastTimestamp;

  AiroHapticDevicePlatform _getPlatformType() {
    if (kIsWeb) return AiroHapticDevicePlatform.web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AiroHapticDevicePlatform.android;
      case TargetPlatform.iOS:
        return AiroHapticDevicePlatform.ios;
      case TargetPlatform.macOS:
        return AiroHapticDevicePlatform.macOS;
      case TargetPlatform.windows:
        return AiroHapticDevicePlatform.windows;
      case TargetPlatform.linux:
        return AiroHapticDevicePlatform.linux;
      case TargetPlatform.fuchsia:
        return AiroHapticDevicePlatform.fuchsia;
    }
  }

  @override
  Future<AiroHapticCapabilities> getCapabilities() async {
    final platform = _getPlatformType();
    try {
      final res = await channel.invokeMapMethod<String, dynamic>('getCapabilities');
      if (res != null) {
        return AiroHapticCapabilities.fromJson(res);
      }
    } on MissingPluginException catch (_) {
      // Graceful fallback for platforms without native implementation plugin registered.
    } on PlatformException catch (_) {}

    // Safe fallback based on OS default availability.
    if (platform == AiroHapticDevicePlatform.android || platform == AiroHapticDevicePlatform.ios) {
      return AiroHapticCapabilities.basicOnly(platform: platform, backend: 'flutter_services_fallback');
    }

    return AiroHapticCapabilities.unsupported(platform: platform);
  }

  @override
  Future<void> performFeedback(
    AiroHapticFeedbackType type, {
    AiroHapticOptions? options,
  }) async {
    _totalTriggers++;
    _lastType = type.name;
    _lastTimestamp = DateTime.now();

    try {
      await channel.invokeMethod<void>('performFeedback', {
        'type': type.name,
        'options': options?.toJson(),
      });
      _playedCount++;
      return;
    } on MissingPluginException catch (_) {
      final played = await _fallbackSystemFeedback(type);
      if (played) {
        _playedCount++;
      } else {
        _droppedCount++;
      }
    } on PlatformException catch (_) {
      _droppedCount++;
    }
  }

  @override
  Future<void> performImpact(
    AiroHapticImpact impact, {
    double? intensity,
    AiroHapticOptions? options,
  }) async {
    _totalTriggers++;
    _lastType = 'impact_${impact.name}';
    _lastTimestamp = DateTime.now();

    try {
      await channel.invokeMethod<void>('performImpact', {
        'impact': impact.name,
        'intensity': intensity ?? impact.defaultIntensity,
        'options': options?.toJson(),
      });
      _playedCount++;
      return;
    } on MissingPluginException catch (_) {
      final played = await _fallbackSystemImpact(impact);
      if (played) {
        _playedCount++;
      } else {
        _droppedCount++;
      }
    } on PlatformException catch (_) {
      _droppedCount++;
    }
  }

  @override
  Future<void> playPattern(
    AiroHapticPattern pattern, {
    AiroHapticOptions? options,
  }) async {
    _totalTriggers++;
    _lastType = 'pattern_${pattern.id}';
    _lastTimestamp = DateTime.now();

    try {
      await channel.invokeMethod<void>('playPattern', {
        'pattern': pattern.toJson(),
        'options': options?.toJson(),
      });
      _playedCount++;
    } on MissingPluginException catch (_) {
      if (pattern.events.isNotEmpty) {
        await HapticFeedback.vibrate();
        _playedCount++;
      } else {
        _droppedCount++;
      }
    } on PlatformException catch (_) {
      _droppedCount++;
    }
  }

  @override
  Future<void> updatePattern(String patternId, double intensity, double sharpness) async {
    try {
      await channel.invokeMethod<void>('updatePattern', {
        'patternId': patternId,
        'intensity': intensity,
        'sharpness': sharpness,
      });
    } on Exception catch (_) {}
  }

  @override
  Future<void> stopPattern(String patternId) async {
    try {
      await channel.invokeMethod<void>('stopPattern', {'patternId': patternId});
    } on Exception catch (_) {}
  }

  @override
  Future<void> stopAll() async {
    try {
      await channel.invokeMethod<void>('stopAll');
    } on Exception catch (_) {}
  }

  @override
  Future<void> updateSettings(AiroHapticSettings settings) async {
    try {
      await channel.invokeMethod<void>('updateSettings', settings.toJson());
    } on Exception catch (_) {}
  }

  @override
  Future<AiroHapticDiagnostics> getDiagnostics() async {
    try {
      final res = await channel.invokeMapMethod<String, dynamic>('getDiagnostics');
      if (res != null) {
        return AiroHapticDiagnostics.fromJson(res);
      }
    } on Exception catch (_) {}

    return AiroHapticDiagnostics(
      totalTriggers: _totalTriggers,
      playedCount: _playedCount,
      droppedCount: _droppedCount,
      activeBackend: 'method_channel_fallback',
      lastTriggeredType: _lastType,
      lastTriggerTimestamp: _lastTimestamp,
    );
  }

  Future<bool> _fallbackSystemFeedback(AiroHapticFeedbackType type) async {
    switch (type) {
      case AiroHapticFeedbackType.selection:
      case AiroHapticFeedbackType.focus:
      case AiroHapticFeedbackType.press:
        await HapticFeedback.selectionClick();
        return true;
      case AiroHapticFeedbackType.impact:
      case AiroHapticFeedbackType.confirm:
      case AiroHapticFeedbackType.toggleOn:
      case AiroHapticFeedbackType.toggleOff:
        await HapticFeedback.lightImpact();
        return true;
      case AiroHapticFeedbackType.success:
      case AiroHapticFeedbackType.completion:
        await HapticFeedback.mediumImpact();
        return true;
      case AiroHapticFeedbackType.warning:
      case AiroHapticFeedbackType.error:
      case AiroHapticFeedbackType.failure:
      case AiroHapticFeedbackType.reject:
      case AiroHapticFeedbackType.delete:
        await HapticFeedback.heavyImpact();
        return true;
      case AiroHapticFeedbackType.longPress:
      case AiroHapticFeedbackType.dragStart:
      case AiroHapticFeedbackType.dragEnd:
      case AiroHapticFeedbackType.refresh:
      case AiroHapticFeedbackType.notification:
      case AiroHapticFeedbackType.navigation:
      case AiroHapticFeedbackType.boundary:
        await HapticFeedback.vibrate();
        return true;
    }
  }

  Future<bool> _fallbackSystemImpact(AiroHapticImpact impact) async {
    switch (impact) {
      case AiroHapticImpact.light:
      case AiroHapticImpact.soft:
        await HapticFeedback.lightImpact();
        return true;
      case AiroHapticImpact.medium:
        await HapticFeedback.mediumImpact();
        return true;
      case AiroHapticImpact.heavy:
      case AiroHapticImpact.rigid:
        await HapticFeedback.heavyImpact();
        return true;
    }
  }
}
