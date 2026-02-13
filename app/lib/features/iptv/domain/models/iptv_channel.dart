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
  international('International'),
  lifestyle('Lifestyle'),
  devotional('Devotional'),
  business('Business'),
  general('General');

  const ChannelCategory(this.label);
  final String label;

  /// Parse category from string
  static ChannelCategory fromString(String value) {
    return ChannelCategory.values.firstWhere(
      (c) => c.name.toLowerCase() == value.toLowerCase(),
      orElse: () => ChannelCategory.general,
    );
  }
}

/// Channel flavor for taste-based filtering
enum ChannelFlavor {
  hindiMusic('Hindi Music'),
  englishMusic('English Music'),
  hindiNews('Hindi News'),
  englishNews('English News'),
  hindiEntertainment('Hindi Entertainment'),
  regionalEntertainment('Regional Entertainment'),
  sports('Sports'),
  movies('Movies'),
  kids('Kids'),
  devotional('Devotional'),
  lifestyle('Lifestyle'),
  general('General');

  const ChannelFlavor(this.label);
  final String label;

  /// Parse flavor from string
  static ChannelFlavor fromString(String value) {
    return ChannelFlavor.values.firstWhere(
      (c) => c.name == value,
      orElse: () => ChannelFlavor.general,
    );
  }
}

/// HTTP headers for stream access
class ChannelHeaders extends Equatable {
  final String? userAgent;
  final String? referrer;

  const ChannelHeaders({this.userAgent, this.referrer});

  factory ChannelHeaders.fromJson(Map<String, dynamic> json) {
    return ChannelHeaders(
      userAgent: json['userAgent'] as String?,
      referrer: json['referrer'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (userAgent != null) 'userAgent': userAgent,
    if (referrer != null) 'referrer': referrer,
  };

  @override
  List<Object?> get props => [userAgent, referrer];
}

/// IPTV Channel model
class IPTVChannel extends Equatable {
  final String id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String group;
  final ChannelCategory category;
  final ChannelFlavor flavor;
  final String country;
  final bool isAudioOnly;
  final List<String> languages;
  final Map<String, String>? qualityUrls;
  final int? tvgId;
  final String? tvgName;
  final DateTime? lastChecked;
  final bool isWorking;
  final ChannelHeaders? headers;
  final List<String> sources;
  final List<String> altNames;

  const IPTVChannel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.group = 'Uncategorized',
    this.category = ChannelCategory.all,
    this.flavor = ChannelFlavor.general,
    this.country = 'IN',
    this.isAudioOnly = false,
    this.languages = const ['en'],
    this.qualityUrls,
    this.tvgId,
    this.tvgName,
    this.lastChecked,
    this.isWorking = true,
    this.headers,
    this.sources = const [],
    this.altNames = const [],
  });

  /// Create from preprocessed JSON (from IPTV Sanity Agent)
  factory IPTVChannel.fromJson(Map<String, dynamic> json) {
    return IPTVChannel(
      id: json['id'] as String,
      name: json['name'] as String,
      streamUrl: json['streamUrl'] as String,
      logoUrl: json['logoUrl'] as String?,
      group: json['group'] as String? ?? 'Uncategorized',
      category: ChannelCategory.fromString(
        json['category'] as String? ?? 'general',
      ),
      flavor: ChannelFlavor.fromString(json['flavor'] as String? ?? 'general'),
      country: json['country'] as String? ?? 'IN',
      isAudioOnly: json['isAudioOnly'] as bool? ?? false,
      languages:
          (json['languages'] as List<dynamic>?)?.cast<String>() ?? const ['en'],
      qualityUrls: (json['qualityUrls'] as Map<String, dynamic>?)
          ?.cast<String, String>(),
      tvgId: json['tvgId'] as int?,
      tvgName: json['tvgName'] as String?,
      isWorking: json['isWorking'] as bool? ?? true,
      headers: json['headers'] != null
          ? ChannelHeaders.fromJson(json['headers'] as Map<String, dynamic>)
          : null,
      sources: (json['sources'] as List<dynamic>?)?.cast<String>() ?? const [],
      altNames:
          (json['altNames'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'streamUrl': streamUrl,
    if (logoUrl != null) 'logoUrl': logoUrl,
    'group': group,
    'category': category.name,
    'flavor': flavor.name,
    'country': country,
    'isAudioOnly': isAudioOnly,
    'languages': languages,
    if (qualityUrls != null) 'qualityUrls': qualityUrls,
    if (tvgId != null) 'tvgId': tvgId,
    if (tvgName != null) 'tvgName': tvgName,
    'isWorking': isWorking,
    if (headers != null) 'headers': headers!.toJson(),
    if (sources.isNotEmpty) 'sources': sources,
    if (altNames.isNotEmpty) 'altNames': altNames,
  };

  /// Check if channel supports multiple quality levels
  bool get hasMultipleQualities =>
      qualityUrls != null && qualityUrls!.length > 1;

  /// Get stream URL for specific quality
  String getStreamUrl([VideoQuality quality = VideoQuality.auto]) {
    if (quality == VideoQuality.auto || qualityUrls == null) {
      return streamUrl;
    }
    return qualityUrls![quality.name] ?? streamUrl;
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
    ChannelFlavor? flavor,
    String? country,
    bool? isAudioOnly,
    List<String>? languages,
    Map<String, String>? qualityUrls,
    int? tvgId,
    String? tvgName,
    DateTime? lastChecked,
    bool? isWorking,
    ChannelHeaders? headers,
    List<String>? sources,
    List<String>? altNames,
  }) {
    return IPTVChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      streamUrl: streamUrl ?? this.streamUrl,
      logoUrl: logoUrl ?? this.logoUrl,
      group: group ?? this.group,
      category: category ?? this.category,
      flavor: flavor ?? this.flavor,
      country: country ?? this.country,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
      languages: languages ?? this.languages,
      qualityUrls: qualityUrls ?? this.qualityUrls,
      tvgId: tvgId ?? this.tvgId,
      tvgName: tvgName ?? this.tvgName,
      lastChecked: lastChecked ?? this.lastChecked,
      isWorking: isWorking ?? this.isWorking,
      headers: headers ?? this.headers,
      sources: sources ?? this.sources,
      altNames: altNames ?? this.altNames,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    streamUrl,
    group,
    category,
    flavor,
    country,
  ];
}
