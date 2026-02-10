import 'package:equatable/equatable.dart';

/// Video quality levels for adaptive bitrate streaming
enum VideoQuality {
  auto('Auto', 0),
  low('360p', 360),
  medium('480p', 480),
  high('720p', 720),
  fullHd('1080p', 1080),
  ultraHd('4K', 2160);

  const VideoQuality(this.label, this.height);
  final String label;
  final int height;
}

/// Channel category for filtering
enum ChannelCategory {
  all('All'),
  news('News'),
  entertainment('Entertainment'),
  sports('Sports'),
  music('Music'),
  movies('Movies'),
  kids('Kids'),
  documentary('Documentary'),
  regional('Regional'),
  international('International');

  const ChannelCategory(this.label);
  final String label;
}

/// IPTV Channel model
class IPTVChannel extends Equatable {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String group;
  final ChannelCategory category;
  final bool isAudioOnly;
  final List<String> languages;
  final Map<VideoQuality, String>? qualityUrls;
  final int? tvgId;
  final String? tvgName;
  final DateTime? lastChecked;
  final bool isWorking;

  const IPTVChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.group = 'Uncategorized',
    this.category = ChannelCategory.all,
    this.isAudioOnly = false,
    this.languages = const ['en'],
    this.qualityUrls,
    this.tvgId,
    this.tvgName,
    this.lastChecked,
    this.isWorking = true,
  });

  /// Check if channel supports multiple quality levels
  bool get hasMultipleQualities =>
      qualityUrls != null && qualityUrls!.length > 1;

  /// Get stream URL for specific quality
  String getStreamUrl([VideoQuality quality = VideoQuality.auto]) {
    if (quality == VideoQuality.auto || qualityUrls == null) {
      return streamUrl;
    }
    return qualityUrls![quality] ?? streamUrl;
  }

  /// Create from M3U entry
  factory IPTVChannel.fromM3U({
    required String name,
    required String url,
    String? logo,
    String? group,
    String? tvgId,
    String? tvgName,
    String? language,
  }) {
    return IPTVChannel(
      id: url.hashCode.toString(),
      name: name,
      streamUrl: url,
      logoUrl: logo,
      group: group ?? 'Uncategorized',
      category: _inferCategory(group ?? '', name),
      isAudioOnly: _isAudioStream(url, group, name),
      languages: language != null ? [language] : const ['en'],
      tvgId: tvgId != null ? int.tryParse(tvgId) : null,
      tvgName: tvgName,
    );
  }

  static ChannelCategory _inferCategory(String group, [String? name]) {
    final g = group.toLowerCase();
    final n = (name ?? '').toLowerCase();

    // Check both group and name for better classification
    final combined = '$g $n';

    // Music channels - check for known music channel names
    if (_isMusicChannel(combined)) return ChannelCategory.music;

    if (combined.contains('news')) return ChannelCategory.news;
    if (combined.contains('sport')) return ChannelCategory.sports;
    if (combined.contains('movie') || combined.contains('cinema')) {
      return ChannelCategory.movies;
    }
    if (combined.contains('kid') || combined.contains('cartoon')) {
      return ChannelCategory.kids;
    }
    if (combined.contains('doc')) return ChannelCategory.documentary;
    if (combined.contains('entertainment')) {
      return ChannelCategory.entertainment;
    }
    return ChannelCategory.all;
  }

  /// Check if channel is a music channel based on name patterns
  static bool _isMusicChannel(String text) {
    // Known music channel patterns
    const musicPatterns = [
      'music',
      'mtv',
      '9xm',
      '9x jalwa',
      'b4u music',
      'b4u beats',
      'vh1',
      'mastiii',
      'zing',
      'radio',
      'fm',
      'hits',
      'bollywood music',
      'punjabi music',
      'gaana',
      'saavn',
      'hungama music',
    ];

    for (final pattern in musicPatterns) {
      if (text.contains(pattern)) return true;
    }
    return false;
  }

  static bool _isAudioStream(String url, String? group, [String? name]) {
    final u = url.toLowerCase();
    final g = (group ?? '').toLowerCase();
    final n = (name ?? '').toLowerCase();
    final combined = '$g $n';

    return u.contains('radio') ||
        u.endsWith('.mp3') ||
        u.endsWith('.aac') ||
        combined.contains('radio') ||
        combined.contains('fm ');
  }

  IPTVChannel copyWith({
    String? id,
    String? name,
    String? streamUrl,
    String? logoUrl,
    String? group,
    ChannelCategory? category,
    bool? isAudioOnly,
    List<String>? languages,
    Map<VideoQuality, String>? qualityUrls,
    int? tvgId,
    String? tvgName,
    DateTime? lastChecked,
    bool? isWorking,
  }) {
    return IPTVChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      group: group ?? this.group,
      category: category ?? this.category,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      languages: languages ?? this.languages,
      qualityUrls: qualityUrls ?? this.qualityUrls,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      lastChecked: lastChecked ?? this.lastChecked,
      isWorking: isWorking ?? this.isWorking,
    );
  }

  @override
  List<Object?> get props => [id, name, streamUrl, group, category];
}
