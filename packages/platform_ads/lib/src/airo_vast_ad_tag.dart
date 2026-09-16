/// Model representing a VAST / VMAP Ad Tag URL or parsed VAST descriptor.
class AiroVastAdTag {
  const AiroVastAdTag({
    required this.tagUrl,
    this.adSystem,
    this.adTitle,
    this.impressionUrls = const [],
    this.trackingEvents = const {},
    this.mediaFileUrl,
  });

  /// Constructs a Google Ad Manager VAST tag URL given custom parameters.
  factory AiroVastAdTag.googleAdManager({
    required String adUnitPath,
    required String descriptionUrl,
    int width = 640,
    int height = 480,
    bool isLive = false,
  }) {
    final uri = Uri.https('pubads.g.doubleclick.net', '/gampad/ads', {
      'iu': adUnitPath,
      'description_url': descriptionUrl,
      'tfcd': '0',
      'npa': '0',
      'sz': '${width}x$height',
      'gdfp_req': '1',
      'output': 'vast',
      'unviewed_position_start': '1',
      'env': 'vp',
      'impl': 's',
      'live': isLive ? '1' : '0',
      'correlator': DateTime.now().millisecondsSinceEpoch.toString(),
    });

    return AiroVastAdTag(tagUrl: uri.toString());
  }

  final String tagUrl;
  final String? adSystem;
  final String? adTitle;
  final List<String> impressionUrls;
  final Map<String, String> trackingEvents;
  final String? mediaFileUrl;

  /// Diagnostic map representation.
  Map<String, dynamic> toDiagnosticMap() {
    return {
      'tagUrl': tagUrl,
      'adSystem': adSystem,
      'adTitle': adTitle,
      'impressionUrls': impressionUrls,
      'trackingEvents': trackingEvents,
      'mediaFileUrl': mediaFileUrl,
    };
  }
}

/// Parser for VAST / VMAP XML responses.
class AiroVastTagParser {
  /// Parses a VAST XML response string into an [AiroVastAdTag].
  static AiroVastAdTag parseXml({
    required String tagUrl,
    required String xmlContent,
  }) {
    final adSystemMatch = RegExp('<AdSystem>(.*?)</AdSystem>').firstMatch(xmlContent);
    final adTitleMatch = RegExp('<AdTitle>(.*?)</AdTitle>').firstMatch(xmlContent);
    final mediaFileMatch = RegExp('<MediaFile[^>]*>(.*?)</MediaFile>').firstMatch(xmlContent);

    final impressionMatches = RegExp('<Impression[^>]*>(.*?)</Impression>').allMatches(xmlContent);
    final impressionUrls = impressionMatches
        .map((m) => m.group(1)?.trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();

    return AiroVastAdTag(
      tagUrl: tagUrl,
      adSystem: adSystemMatch?.group(1)?.trim(),
      adTitle: adTitleMatch?.group(1)?.trim(),
      impressionUrls: impressionUrls,
      mediaFileUrl: mediaFileMatch?.group(1)?.trim(),
    );
  }
}

/// Unified player ad adapter interface for feeding VAST/VMAP ad tags into video players.
abstract class AiroUnifiedPlayerAdAdapter {
  /// Binds a VAST ad tag to the active video player instance.
  Future<bool> loadVastAdTag(AiroVastAdTag adTag);

  /// Reports ad impression to VAST tracking endpoint.
  Future<void> reportImpression(AiroVastAdTag adTag);

  /// Clears active VAST ad tag.
  void clear();
}
