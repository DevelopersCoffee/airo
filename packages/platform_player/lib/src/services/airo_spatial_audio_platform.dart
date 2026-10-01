import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter/services.dart';

import '../models/playback_engine_models.dart';
import '../models/spatial_audio_models.dart';

/// Method-channel bridge for the TV Media3 PCM tap (`tv` flavor).
///
/// Phone/Coins/web builds compile the stub Kotlin object and always report
/// [AiroSpatialAudioTapKind.unavailable] without throwing.
class AiroSpatialAudioPlatform {
  AiroSpatialAudioPlatform._();

  static MethodChannel _channel = const MethodChannel(
    'com.airo.player/spatial_audio',
  );

  static Future<AiroSpatialAudioTapStatus?> queryTapStatus() async {
    try {
      final raw = await _channel.invokeMapMethod<String, Object?>(
        'spatialAudioTapStatus',
      );
      return _parseTapStatus(raw);
    } on MissingPluginException {
      debugPrint('Spatial audio channel is unavailable on this host');
      return null;
    } catch (error) {
      debugPrint('Spatial audio tapStatus error: $error');
      return null;
    }
  }

  static Future<void> setSpatialAudioMode(AiroSpatialAudioMode mode) async {
    try {
      await _channel.invokeMethod<void>('setSpatialAudioMode', {
        'mode': mode.stableId,
      });
    } on MissingPluginException {
      debugPrint('Spatial audio channel is unavailable on this host');
    } catch (error) {
      debugPrint('Spatial audio setMode error: $error');
    }
  }

  static AiroSpatialAudioTapStatus? _parseTapStatus(Map<String, Object?>? raw) {
    if (raw == null) return null;
    final backendKind = _backendFromStableId(raw['backend'] as String?);
    final tapKind = AiroSpatialAudioTapKind.fromStableId(
      raw['tapKind'] as String?,
    );
    if (tapKind == null || backendKind == null) return null;
    final detailCodes =
        (raw['detailCodes'] as List<Object?>?)
            ?.whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    return AiroSpatialAudioTapStatus(
      backendKind: backendKind,
      tapKind: tapKind,
      detailCodes: detailCodes,
      processorInstalled: raw['processorInstalled'] == true,
      framesProcessed: (raw['framesProcessed'] as num?)?.toInt() ?? 0,
    );
  }

  static AiroPlaybackBackendKind? _backendFromStableId(String? stableId) {
    if (stableId == null) return null;
    for (final kind in AiroPlaybackBackendKind.values) {
      if (kind.stableId == stableId) return kind;
    }
    return null;
  }

  @visibleForTesting
  static void debugSetMethodChannel(MethodChannel channel) {
    _channel = channel;
  }
}
