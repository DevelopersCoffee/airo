import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

/// Merges multiple channel libraries (one list per configured source) into
/// one Live TV list. Defaults to exact `id`/`streamUrl` dedup — the
/// airo-pro overlay overrides this provider (via `ProviderScope.overrides`
/// at bootstrap) to add cross-provider identity matching gated behind
/// `ProFeature.importIntelligence`, without editing this file directly, so
/// upstream syncs never conflict here.
final channelLibraryMergerProvider =
    Provider<List<IPTVChannel> Function(Iterable<List<IPTVChannel>>)>(
      (ref) => mergeChannelLibraries,
    );

/// Exact `id`/`streamUrl` merge: channels sharing either key are folded
/// into one entry with the union of their stream sources, languages,
/// alt names, and categories.
List<IPTVChannel> mergeChannelLibraries(
  Iterable<List<IPTVChannel>> libraries,
) {
  final channelsById = <String, IPTVChannel>{};
  final channelIdByStreamUrl = <String, String>{};

  for (final library in libraries) {
    for (final channel in library) {
      final existingId = channelsById.containsKey(channel.id)
          ? channel.id
          : channelIdByStreamUrl[channel.streamUrl];
      if (existingId == null) {
        channelsById[channel.id] = channel;
        channelIdByStreamUrl[channel.streamUrl] = channel.id;
        continue;
      }

      final existing = channelsById[existingId]!;
      final streamSources = <String, ChannelStreamSource>{
        for (final source in existing.streamSources) source.url: source,
        for (final source in channel.streamSources) source.url: source,
      };
      for (final url in [
        existing.streamUrl,
        ...existing.sources,
        channel.streamUrl,
        ...channel.sources,
      ]) {
        streamSources.putIfAbsent(url, () => ChannelStreamSource(url: url));
        channelIdByStreamUrl[url] = existingId;
      }
      final orderedSources = streamSources.values.toList()
        ..sort(compareChannelStreamSources);

      channelsById[existingId] = existing.copyWith(
        sources: orderedSources.map((source) => source.url).toList(),
        streamSources: orderedSources,
        qualityUrls: {
          ...?existing.qualityUrls,
          ...?channel.qualityUrls,
          for (var index = 1; index < orderedSources.length; index++)
            'source-$index': orderedSources[index].url,
        },
        languages: {...existing.languages, ...channel.languages}.toList(),
        altNames: {...existing.altNames, ...channel.altNames}.toList(),
        categories: {...existing.categories, ...channel.categories}.toList(),
        isWorking: existing.isWorking || channel.isWorking,
      );
    }
  }

  return List.unmodifiable(channelsById.values);
}
