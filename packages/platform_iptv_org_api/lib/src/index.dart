import 'dart:collection';

import 'models.dart';

enum IptvOrgNsfwPolicy { exclude, include }

final class IptvOrgIndex {
  IptvOrgIndex(this.snapshot)
    : channelById = _uniqueBy(snapshot.channels, (value) => value.id),
      categoryById = _uniqueBy(snapshot.categories, (value) => value.id),
      languageByCode = _uniqueBy(snapshot.languages, (value) => value.code),
      countryByCode = _uniqueBy(snapshot.countries, (value) => value.code),
      subdivisionByCode = _uniqueBy(
        snapshot.subdivisions,
        (value) => value.code,
      ),
      cityByCode = _uniqueBy(snapshot.cities, (value) => value.code),
      regionByCode = _uniqueBy(snapshot.regions, (value) => value.code),
      timezoneById = _uniqueBy(snapshot.timezones, (value) => value.id),
      _feedsByChannel = _groupBy(snapshot.feeds, (value) => value.channel),
      _logosByChannel = _groupBy(snapshot.logos, (value) => value.channel),
      _streamsByChannel = _groupByNullable(
        snapshot.streams,
        (value) => value.channel,
      ),
      _guidesByChannel = _groupByNullable(
        snapshot.guides,
        (value) => value.channel,
      ),
      _blocksByChannel = _groupBy(snapshot.blocklist, (value) => value.channel);

  final IptvOrgSnapshot snapshot;
  final Map<String, IptvOrgChannel> channelById;
  final Map<String, IptvOrgCategory> categoryById;
  final Map<String, IptvOrgLanguage> languageByCode;
  final Map<String, IptvOrgCountry> countryByCode;
  final Map<String, IptvOrgSubdivision> subdivisionByCode;
  final Map<String, IptvOrgCity> cityByCode;
  final Map<String, IptvOrgRegion> regionByCode;
  final Map<String, IptvOrgTimezone> timezoneById;
  final Map<String, List<IptvOrgFeed>> _feedsByChannel;
  final Map<String, List<IptvOrgLogo>> _logosByChannel;
  final Map<String, List<IptvOrgStream>> _streamsByChannel;
  final Map<String, List<IptvOrgGuide>> _guidesByChannel;
  final Map<String, List<IptvOrgBlocklistEntry>> _blocksByChannel;

  List<IptvOrgFeed> feedsForChannel(String channelId) =>
      _feedsByChannel[channelId] ?? const [];

  IptvOrgFeed? preferredFeed(
    String channelId, {
    String? countryCode,
    String? subdivisionCode,
    String? regionCode,
  }) {
    final feeds = [...feedsForChannel(channelId)];
    feeds.sort((left, right) {
      final regionCompare =
          _feedAreaScore(
            right,
            countryCode: countryCode,
            subdivisionCode: subdivisionCode,
            regionCode: regionCode,
          ).compareTo(
            _feedAreaScore(
              left,
              countryCode: countryCode,
              subdivisionCode: subdivisionCode,
              regionCode: regionCode,
            ),
          );
      if (regionCompare != 0) return regionCompare;
      final mainCompare = _boolScore(
        right.isMain,
      ).compareTo(_boolScore(left.isMain));
      if (mainCompare != 0) return mainCompare;
      return left.id.compareTo(right.id);
    });
    return feeds.firstOrNull;
  }

  IptvOrgLogo? preferredLogo(String channelId, {String? feedId}) {
    final logos = [...?_logosByChannel[channelId]];
    logos.sort((left, right) {
      final feedCompare = _boolScore(
        right.feed == feedId && feedId != null,
      ).compareTo(_boolScore(left.feed == feedId && feedId != null));
      if (feedCompare != 0) return feedCompare;
      final useCompare = _boolScore(
        right.inUse,
      ).compareTo(_boolScore(left.inUse));
      if (useCompare != 0) return useCompare;
      final formatCompare = _logoFormatScore(
        right.format,
      ).compareTo(_logoFormatScore(left.format));
      if (formatCompare != 0) return formatCompare;
      final areaCompare = (right.width * right.height).compareTo(
        left.width * left.height,
      );
      if (areaCompare != 0) return areaCompare;
      return left.url.compareTo(right.url);
    });
    return logos.firstOrNull;
  }

  List<IptvOrgStream> streamsForChannel(
    String channelId, {
    String? preferredFeedId,
  }) {
    final streams = [...?_streamsByChannel[channelId]];
    streams.sort((left, right) {
      final feedCompare =
          _boolScore(
            right.feed == preferredFeedId && preferredFeedId != null,
          ).compareTo(
            _boolScore(left.feed == preferredFeedId && preferredFeedId != null),
          );
      if (feedCompare != 0) return feedCompare;
      final qualityCompare = _qualityScore(
        right.quality,
      ).compareTo(_qualityScore(left.quality));
      if (qualityCompare != 0) return qualityCompare;
      final labelCompare = _boolScore(
        right.label == null,
      ).compareTo(_boolScore(left.label == null));
      if (labelCompare != 0) return labelCompare;
      return left.url.compareTo(right.url);
    });
    return List.unmodifiable(streams);
  }

  List<IptvOrgGuide> guidesForChannel(
    String channelId, {
    String? preferredFeedId,
    String? languageCode,
  }) {
    final guides = [...?_guidesByChannel[channelId]];
    guides.sort((left, right) {
      final feedCompare =
          _boolScore(
            right.feed == preferredFeedId && preferredFeedId != null,
          ).compareTo(
            _boolScore(left.feed == preferredFeedId && preferredFeedId != null),
          );
      if (feedCompare != 0) return feedCompare;
      final languageCompare =
          _boolScore(
            right.lang == languageCode && languageCode != null,
          ).compareTo(
            _boolScore(left.lang == languageCode && languageCode != null),
          );
      if (languageCompare != 0) return languageCompare;
      final siteCompare = left.site.compareTo(right.site);
      return siteCompare != 0
          ? siteCompare
          : left.siteId.compareTo(right.siteId);
    });
    return List.unmodifiable(guides);
  }

  bool isBlocked(
    String channelId, {
    IptvOrgNsfwPolicy nsfwPolicy = IptvOrgNsfwPolicy.exclude,
  }) {
    final channel = channelById[channelId];
    if (channel?.isNsfw == true && nsfwPolicy == IptvOrgNsfwPolicy.exclude) {
      return true;
    }
    for (final entry in _blocksByChannel[channelId] ?? const []) {
      if (entry.reason == IptvOrgBlockReason.dmca) return true;
      if (entry.reason == IptvOrgBlockReason.nsfw &&
          nsfwPolicy == IptvOrgNsfwPolicy.exclude) {
        return true;
      }
    }
    return false;
  }
}

Map<String, T> _uniqueBy<T>(Iterable<T> values, String Function(T) keyOf) {
  final result = <String, T>{};
  for (final value in values) {
    result.putIfAbsent(keyOf(value), () => value);
  }
  return UnmodifiableMapView(result);
}

Map<String, List<T>> _groupBy<T>(Iterable<T> values, String Function(T) keyOf) {
  final result = <String, List<T>>{};
  for (final value in values) {
    (result[keyOf(value)] ??= []).add(value);
  }
  return UnmodifiableMapView({
    for (final entry in result.entries)
      entry.key: List<T>.unmodifiable(entry.value),
  });
}

Map<String, List<T>> _groupByNullable<T>(
  Iterable<T> values,
  String? Function(T) keyOf,
) => _groupBy(values.where((value) => keyOf(value) != null), (value) {
  return keyOf(value)!;
});

int _boolScore(bool value) => value ? 1 : 0;

int _feedAreaScore(
  IptvOrgFeed feed, {
  String? countryCode,
  String? subdivisionCode,
  String? regionCode,
}) {
  if (subdivisionCode != null &&
      feed.broadcastArea.contains('s/$subdivisionCode')) {
    return 3;
  }
  if (countryCode != null && feed.broadcastArea.contains('c/$countryCode')) {
    return 2;
  }
  if (regionCode != null && feed.broadcastArea.contains('r/$regionCode')) {
    return 1;
  }
  return 0;
}

int _logoFormatScore(String? format) => switch (format?.toUpperCase()) {
  'SVG' => 4,
  'PNG' || 'WEBP' || 'AVIF' => 3,
  'JPEG' || 'APNG' => 2,
  'GIF' => 1,
  _ => 0,
};

int _qualityScore(String? quality) {
  if (quality == null) return 0;
  final normalized = quality.toLowerCase();
  if (normalized.contains('2160') || normalized.contains('4k')) return 2160;
  final match = RegExp(r'(\d{3,4})[pi]').firstMatch(normalized);
  return int.tryParse(match?.group(1) ?? '') ?? 0;
}
