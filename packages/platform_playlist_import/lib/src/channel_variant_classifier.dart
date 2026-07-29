import 'package:core_native/core_native.dart';
import 'package:platform_channels/platform_channels.dart';

enum ChannelVariantRelationship { distinct, duplicate, variant }

/// Pure, deterministic BYOC classifier. Parsing stays in core_native; this
/// boundary owns conservative grouping and lossless source retention.
final class ChannelVariantClassifier {
  const ChannelVariantClassifier();

  static final BigInt _fnv64OffsetBasis = BigInt.parse(
    'cbf29ce484222325',
    radix: 16,
  );
  static final BigInt _fnv64Prime = BigInt.parse('100000001b3', radix: 16);
  static final BigInt _uint64Mask = (BigInt.one << 64) - BigInt.one;

  String canonicalName(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAll(
      RegExp(r'\(\s*(?:\d{3,4}p|hd|fhd|uhd|4k|sd)\s*\)\s*$'),
      '',
    );
    normalized = normalized.replaceAll(
      RegExp(r'[\s._-]+(?:\d{3,4}p|hd|fhd|uhd|4k|sd)$'),
      '',
    );
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '');
    return normalized;
  }

  ChannelVariantRelationship classify(
    NativeM3uEntry left,
    NativeM3uEntry right,
  ) {
    if (_scope(left) != _scope(right)) {
      return ChannelVariantRelationship.distinct;
    }
    final leftIdentity = _upstreamIdentity(left);
    final rightIdentity = _upstreamIdentity(right);
    final sameIdentity =
        leftIdentity != null &&
        rightIdentity != null &&
        leftIdentity == rightIdentity;
    if (!sameIdentity &&
        _canonicalEntryName(left) != _canonicalEntryName(right)) {
      return ChannelVariantRelationship.distinct;
    }
    final leftFeed = _feedId(left);
    final rightFeed = _feedId(right);
    if (leftFeed != null && rightFeed != null && leftFeed != rightFeed) {
      return ChannelVariantRelationship.variant;
    }
    return left.url.trim() == right.url.trim()
        ? ChannelVariantRelationship.duplicate
        : ChannelVariantRelationship.variant;
  }

  List<IPTVChannel> merge(Iterable<NativeM3uEntry> entries) {
    final accepted = entries
        .where(
          (entry) =>
              AiroPlaylistUrlPolicy.normalizeStreamUrl(entry.url) != null,
        )
        .toList(growable: false);
    return List.unmodifiable([
      for (final group in _groups(accepted)) _mergeGroup(group),
    ]);
  }

  List<List<NativeM3uEntry>> _groups(List<NativeM3uEntry> entries) {
    final parents = List<int>.generate(entries.length, (index) => index);
    int find(int index) {
      while (parents[index] != index) {
        parents[index] = parents[parents[index]];
        index = parents[index];
      }
      return index;
    }

    void union(int left, int right) {
      final leftIdentity = _upstreamIdentity(entries[left]);
      final rightIdentity = _upstreamIdentity(entries[right]);
      if (leftIdentity != null &&
          rightIdentity != null &&
          leftIdentity != rightIdentity) {
        return;
      }
      parents[find(right)] = find(left);
    }

    final ownerByKey = <String, int>{};
    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      final scope = _scope(entry);
      final keys = <String>{
        'name:${_canonicalEntryName(entry)}:$scope',
        if (_upstreamIdentity(entry) case final identity?)
          'id:$identity:$scope',
      };
      for (final key in keys) {
        final owner = ownerByKey[key];
        if (owner == null) {
          ownerByKey[key] = index;
        } else {
          union(index, owner);
        }
      }
    }

    final groupsByRoot = <int, List<NativeM3uEntry>>{};
    for (var index = 0; index < entries.length; index++) {
      groupsByRoot.putIfAbsent(find(index), () => []).add(entries[index]);
    }
    return groupsByRoot.values.toList(growable: false);
  }

  IPTVChannel _mergeGroup(List<NativeM3uEntry> group) {
    final sourcesByUrl = <String, ChannelStreamSource>{};
    for (final entry in group) {
      final uri = AiroPlaylistUrlPolicy.normalizeStreamUrl(entry.url)!;
      final source = _source(entry, uri.toString());
      final existing = sourcesByUrl[source.url];
      if (existing == null ||
          compareChannelStreamSources(source, existing) < 0) {
        sourcesByUrl[source.url] = source;
      }
    }
    final orderedSources = sourcesByUrl.values.toList()
      ..sort(compareChannelStreamSources);
    final primaryUrl = orderedSources.first.url;
    final primaryEntry =
        group
            .where(
              (entry) =>
                  AiroPlaylistUrlPolicy.normalizeStreamUrl(
                    entry.url,
                  )?.toString() ==
                  primaryUrl,
            )
            .firstOrNull ??
        group.first;
    final upstreamIdentity = group
        .map(_upstreamIdentity)
        .whereType<String>()
        .firstOrNull;
    final country = _country(primaryEntry);
    final language = _language(primaryEntry);
    final stableKey =
        upstreamIdentity ??
        '${_canonicalEntryName(primaryEntry)}:$country:$language';
    final displayName = _formatChannelName(primaryEntry.name);
    final aliases = <String>{
      for (final entry in group)
        if (entry.name.trim() != displayName) entry.name.trim(),
      for (final entry in group)
        if (entry.tvgName?.trim().isNotEmpty ?? false) entry.tvgName!.trim(),
    }.toList()..sort();
    final logo = group
        .map((entry) => AiroPlaylistUrlPolicy.normalizeLogoUrl(entry.logo))
        .whereType<Uri>()
        .map((uri) => uri.toString())
        .firstOrNull;
    final channel = IPTVChannel.fromM3U(
      name: displayName,
      url: primaryUrl,
      logo: logo,
      group: primaryEntry.group,
      tvgId: primaryEntry.tvgId,
      tvgName: primaryEntry.tvgName,
      language: primaryEntry.language,
    );
    return channel.copyWith(
      id: _stableId(stableKey),
      country: country.isEmpty ? null : country,
      altNames: aliases,
      categories: {
        for (final entry in group)
          if (entry.group?.trim().isNotEmpty ?? false) entry.group!.trim(),
      }.toList()..sort(),
      provenance: upstreamIdentity == null
          ? ChannelImportProvenance.unmatched
          : ChannelImportProvenance.matched,
      streamSources: orderedSources,
      sources: orderedSources.map((source) => source.url).toList(),
      qualityUrls: {
        for (var index = 1; index < orderedSources.length; index++)
          'source-$index': orderedSources[index].url,
      },
      isWorking: orderedSources.first.health != ChannelSourceHealth.unavailable,
    );
  }

  ChannelStreamSource _source(NativeM3uEntry entry, String url) {
    final extras = entry.extras;
    return ChannelStreamSource(
      url: url,
      health: ChannelSourceHealth.fromJson(
        extras['airo-health'] ?? extras['health'],
      ),
      feedId: _feedId(entry),
      labelCorrect:
          (extras['label-correct'] ?? extras['tvg-label-correct'])
              ?.toLowerCase() ==
          'true',
      framesPerSecond: double.tryParse(extras['fps'] ?? ''),
      height: int.tryParse(
        extras['height'] ?? _qualityHeight(entry.name)?.toString() ?? '',
      ),
      bitrate: int.tryParse(extras['bitrate'] ?? ''),
    );
  }

  int? _qualityHeight(String name) {
    final match = RegExp(r'(\d{3,4})p', caseSensitive: false).firstMatch(name);
    return int.tryParse(match?.group(1) ?? '');
  }

  String _canonicalEntryName(NativeM3uEntry entry) {
    final country = _country(entry);
    var name = entry.name;
    if (country.isNotEmpty) {
      name = name.replaceFirst(
        RegExp('[-_. ]${RegExp.escape(country)}\$', caseSensitive: false),
        '',
      );
    }
    return canonicalName(name);
  }

  String _formatChannelName(String name) {
    return name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) {
          if (word.length <= 4 && word == word.toUpperCase()) return word;
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  String _scope(NativeM3uEntry entry) =>
      '${_country(entry)}:${_language(entry)}';

  String _country(NativeM3uEntry entry) =>
      (entry.extras['tvg-country'] ?? entry.extras['country'] ?? '')
          .trim()
          .toUpperCase();

  String _language(NativeM3uEntry entry) =>
      (entry.language ?? entry.extras['tvg-language'] ?? '')
          .trim()
          .toLowerCase();

  String? _upstreamIdentity(NativeM3uEntry entry) {
    final value = entry.tvgId?.trim();
    return value == null || value.isEmpty ? null : value.toLowerCase();
  }

  String? _feedId(NativeM3uEntry entry) {
    final value = (entry.extras['feed-id'] ?? entry.extras['tvg-feed-id'])
        ?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  String _stableId(String value) {
    var hash = _fnv64OffsetBasis;
    for (final byte in value.codeUnits) {
      hash ^= BigInt.from(byte);
      hash = (hash * _fnv64Prime) & _uint64Mask;
    }
    return 'byoc-${hash.toRadixString(16).padLeft(16, '0')}';
  }
}
