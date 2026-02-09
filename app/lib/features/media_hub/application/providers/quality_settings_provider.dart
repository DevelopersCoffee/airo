import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/application/providers/iptv_providers.dart';
import '../../../iptv/domain/models/iptv_channel.dart';
import '../../domain/models/quality_settings.dart';

/// Quality settings notifier for user preferences
class QualitySettingsNotifier extends StateNotifier<QualitySettings> {
  final Ref _ref;
  static const String _storageKey = 'media_hub_quality_settings';

  QualitySettingsNotifier(this._ref) : super(const QualitySettings()) {
    _loadFromStorage();
  }

  /// Set video quality
  void setVideoQuality(VideoQuality quality) {
    state = state.copyWith(videoQuality: quality);
    _saveToStorage();
  }

  /// Set audio language
  void setAudioLanguage(String? language) {
    state = state.copyWith(audioLanguage: language);
    _saveToStorage();
  }

  /// Set playback speed
  void setPlaybackSpeed(double speed) {
    if (!QualitySettings.availableSpeeds.contains(speed)) return;
    state = state.copyWith(playbackSpeed: speed);
    _saveToStorage();
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = const QualitySettings();
    _saveToStorage();
  }

  Future<void> _loadFromStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = QualitySettings.fromJson(json);
      }
    } catch (e) {
      // Failed to load, keep defaults
    }
  }

  Future<void> _saveToStorage() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // Failed to save
    }
  }
}

/// Quality settings provider
final qualitySettingsProvider =
    StateNotifierProvider<QualitySettingsNotifier, QualitySettings>(
      (ref) => QualitySettingsNotifier(ref),
    );

/// Available video quality options
final availableVideoQualitiesProvider = Provider<List<VideoQuality>>((ref) {
  return VideoQuality.values;
});

/// Available playback speeds
final availablePlaybackSpeedsProvider = Provider<List<double>>((ref) {
  return QualitySettings.availableSpeeds;
});
