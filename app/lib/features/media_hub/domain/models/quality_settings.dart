import 'package:equatable/equatable.dart';
import '../../../iptv/domain/models/iptv_channel.dart';

/// User quality preferences for media playback
class QualitySettings extends Equatable {
  /// Video quality preference
  final VideoQuality videoQuality;

  /// Preferred audio language (null = default/auto)
  final String? audioLanguage;

  /// Playback speed multiplier (1.0 = normal)
  final double playbackSpeed;

  const QualitySettings({
    this.videoQuality = VideoQuality.auto,
    this.audioLanguage,
    this.playbackSpeed = 1.0,
  });

  /// Available playback speeds
  static const List<double> availableSpeeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  /// Check if using auto quality
  bool get isAutoQuality => videoQuality == VideoQuality.auto;

  /// Check if using normal speed
  bool get isNormalSpeed => playbackSpeed == 1.0;

  /// Get display label for current speed
  String get speedLabel => '${playbackSpeed}x';

  QualitySettings copyWith({
    VideoQuality? videoQuality,
    String? audioLanguage,
    double? playbackSpeed,
  }) {
    return QualitySettings(
      videoQuality: videoQuality ?? this.videoQuality,
      audioLanguage: audioLanguage ?? this.audioLanguage,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    );
  }

  /// Create from JSON (for persistence)
  factory QualitySettings.fromJson(Map<String, dynamic> json) {
    return QualitySettings(
      videoQuality: VideoQuality.values.firstWhere(
        (q) => q.name == json['videoQuality'],
        orElse: () => VideoQuality.auto,
      ),
      audioLanguage: json['audioLanguage'] as String?,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
    );
  }

  /// Convert to JSON (for persistence)
  Map<String, dynamic> toJson() {
    return {
      'videoQuality': videoQuality.name,
      'audioLanguage': audioLanguage,
      'playbackSpeed': playbackSpeed,
    };
  }

  @override
  List<Object?> get props => [videoQuality, audioLanguage, playbackSpeed];
}

