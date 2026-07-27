import 'package:equatable/equatable.dart';

/// Why a channel record exists after import.
enum ChannelImportProvenance {
  /// Joined to a trusted upstream channel identity.
  matched,

  /// Preserved user content that could not be joined.
  unmatched,

  /// Older records that predate explicit provenance.
  unknown;

  static ChannelImportProvenance fromJson(Object? value) =>
      ChannelImportProvenance.values.firstWhere(
        (candidate) => candidate.name == value,
        orElse: () => ChannelImportProvenance.unknown,
      );
}

/// Explicit stream-health ordering buckets for imported source alternatives.
enum ChannelSourceHealth {
  available,
  restricted,
  unchecked,
  unavailable;

  static ChannelSourceHealth fromJson(Object? value) {
    return switch (value?.toString().toLowerCase()) {
      'available' || 'live' || 'valid' => ChannelSourceHealth.available,
      'restricted' || 'geoblocked' => ChannelSourceHealth.restricted,
      'unavailable' || 'dead' || 'invalid' => ChannelSourceHealth.unavailable,
      _ => ChannelSourceHealth.unchecked,
    };
  }
}

/// One retained source in a merged channel's deterministic failover set.
final class ChannelStreamSource extends Equatable {
  const ChannelStreamSource({
    required this.url,
    this.health = ChannelSourceHealth.unchecked,
    this.feedId,
    this.labelCorrect = false,
    this.framesPerSecond,
    this.height,
    this.bitrate,
    this.quality,
    this.userAgent,
    this.referrer,
  });

  factory ChannelStreamSource.fromJson(Map<String, Object?> json) =>
      ChannelStreamSource(
        url: json['url']! as String,
        health: ChannelSourceHealth.fromJson(json['health']),
        feedId: json['feedId'] as String?,
        labelCorrect: json['labelCorrect'] as bool? ?? false,
        framesPerSecond: (json['framesPerSecond'] as num?)?.toDouble(),
        height: json['height'] as int?,
        bitrate: json['bitrate'] as int?,
        quality: json['quality'] as String? ?? json['actualQuality'] as String?,
        userAgent: json['userAgent'] as String?,
        referrer: json['referrer'] as String?,
      );

  final String url;
  final ChannelSourceHealth health;
  final String? feedId;
  final bool labelCorrect;
  final double? framesPerSecond;
  final int? height;
  final int? bitrate;
  final String? quality;
  final String? userAgent;
  final String? referrer;

  Map<String, Object?> toJson() => {
    'url': url,
    'health': health.name,
    if (feedId != null) 'feedId': feedId,
    'labelCorrect': labelCorrect,
    if (framesPerSecond != null) 'framesPerSecond': framesPerSecond,
    if (height != null) 'height': height,
    if (bitrate != null) 'bitrate': bitrate,
    if (quality != null) 'quality': quality,
    if (userAgent != null) 'userAgent': userAgent,
    if (referrer != null) 'referrer': referrer,
  };

  @override
  List<Object?> get props => [
    url,
    health,
    feedId,
    labelCorrect,
    framesPerSecond,
    height,
    bitrate,
    quality,
    userAgent,
    referrer,
  ];
}

/// Deterministic source preference shared by pipeline and BYOC import.
int compareChannelStreamSources(
  ChannelStreamSource left,
  ChannelStreamSource right,
) {
  final health = left.health.index.compareTo(right.health.index);
  if (health != 0) return health;
  final label = (right.labelCorrect ? 1 : 0) - (left.labelCorrect ? 1 : 0);
  if (label != 0) return label;
  final fps = (right.framesPerSecond ?? -1).compareTo(
    left.framesPerSecond ?? -1,
  );
  if (fps != 0) return fps;
  final height = (right.height ?? -1).compareTo(left.height ?? -1);
  if (height != 0) return height;
  final bitrate = (right.bitrate ?? -1).compareTo(left.bitrate ?? -1);
  if (bitrate != 0) return bitrate;
  return left.url.compareTo(right.url);
}
