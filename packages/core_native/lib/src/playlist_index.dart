import 'package:flutter/foundation.dart' show kIsWeb;

import 'api/m3u.dart' as native_m3u;
import 'api/playlist_engine.dart' as native_engine;
import 'm3u.dart';
import 'native_bridge.dart';

enum NativePlaylistCacheStatus { coldBuilt, warmOpened, indexRebuiltFromCache }

class NativePlaylistIndexDescriptor {
  const NativePlaylistIndexDescriptor({
    required this.indexPath,
    required this.cachePath,
    required this.totalChannels,
    required this.sourceSizeBytes,
    required this.sourceModifiedNanos,
  });

  final String indexPath;
  final String cachePath;
  final int totalChannels;
  final int sourceSizeBytes;
  final int sourceModifiedNanos;
}

class NativeM3uChannelPage {
  const NativeM3uChannelPage({
    required this.channels,
    required this.offset,
    required this.total,
    required this.hasMore,
  });

  final List<NativeM3uChannel> channels;
  final int offset;
  final int total;
  final bool hasMore;
}

enum NativePlaylistSearchField {
  title,
  alias,
  genre,
  language,
  country,
  provider,
  tag,
}

enum NativePlaylistSearchOperator { equals, prefix, contains }

class NativePlaylistSearchFilter {
  const NativePlaylistSearchFilter({
    required this.field,
    required this.operator,
    required this.value,
  });

  final NativePlaylistSearchField field;
  final NativePlaylistSearchOperator operator;
  final String value;
}

class NativePlaylistOpenTimings {
  const NativePlaylistOpenTimings({
    required this.totalMicros,
    required this.sourceMapMicros,
    required this.indexBuildMicros,
    required this.firstPageMicros,
  });

  final int totalMicros;
  final int sourceMapMicros;
  final int indexBuildMicros;
  final int firstPageMicros;
}

class NativePlaylistIndexOpenResult {
  const NativePlaylistIndexOpenResult({
    required this.descriptor,
    required this.firstPage,
    required this.parseStats,
    required this.cacheStatus,
    required this.timings,
  });

  final NativePlaylistIndexDescriptor descriptor;
  final NativeM3uChannelPage firstPage;
  final NativeM3uParseStats parseStats;
  final NativePlaylistCacheStatus cacheStatus;
  final NativePlaylistOpenTimings timings;
}

/// Open the Rust playlist index when the native bridge is available.
///
/// Returns null on web or when the library cannot initialize so callers can
/// use their deterministic worker-backed Dart fallback. Once initialized,
/// engine validation and storage errors are deliberately propagated.
Future<NativePlaylistIndexOpenResult?> openPlaylistIndexNative({
  required String sourcePath,
  required String cacheDirectory,
  int firstPageLimit = 50,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  final result = await native_engine.openPlaylistIndex(
    sourcePath: sourcePath,
    cacheDirectory: cacheDirectory,
    firstPageLimit: firstPageLimit,
  );
  return _mapOpenResult(result);
}

Future<NativeM3uChannelPage?> pagePlaylistIndexNative({
  required String indexPath,
  required int offset,
  int limit = 50,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  return _mapPage(
    await native_engine.pagePlaylistIndex(
      indexPath: indexPath,
      offset: offset,
      limit: limit,
    ),
  );
}

Future<NativeM3uChannelPage?> searchPlaylistIndexNative({
  required String indexPath,
  required String query,
  required int offset,
  int limit = 50,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  return _mapPage(
    await native_engine.searchPlaylistIndex(
      indexPath: indexPath,
      query: query,
      offset: offset,
      limit: limit,
    ),
  );
}

Future<NativeM3uChannelPage?> searchPlaylistIndexV2Native({
  required String indexPath,
  required int offset,
  String? query,
  List<NativePlaylistSearchFilter> filters = const [],
  int limit = 50,
}) async {
  if (kIsWeb || !await initializeCoreNativeBridge()) return null;
  return _mapPage(
    await native_engine.searchPlaylistIndexV2(
      indexPath: indexPath,
      query: query,
      filters: filters
          .map(
            (filter) => native_engine.PlaylistSearchFilter(
              field:
                  native_engine.PlaylistSearchField.values[filter.field.index],
              operator_: native_engine
                  .PlaylistSearchOperator
                  .values[filter.operator.index],
              value: filter.value,
            ),
          )
          .toList(growable: false),
      offset: offset,
      limit: limit,
    ),
  );
}

NativePlaylistIndexOpenResult _mapOpenResult(
  native_engine.PlaylistIndexOpenResult result,
) {
  return NativePlaylistIndexOpenResult(
    descriptor: NativePlaylistIndexDescriptor(
      indexPath: result.descriptor.indexPath,
      cachePath: result.descriptor.cachePath,
      totalChannels: result.descriptor.totalChannels,
      sourceSizeBytes: result.descriptor.sourceSizeBytes.toInt(),
      sourceModifiedNanos: result.descriptor.sourceModifiedNanos.toInt(),
    ),
    firstPage: _mapPage(result.firstPage),
    parseStats: NativeM3uParseStats(
      parsedCount: result.parseStats.parsedCount,
      skippedCount: result.parseStats.skippedCount,
      malformedCount: result.parseStats.malformedCount,
      // PlatformInt64 is int on native and BigInt on web.
      // ignore: noop_primitive_operations
      elapsedMillis: result.parseStats.elapsedMillis.toInt(),
    ),
    cacheStatus: switch (result.cacheStatus) {
      native_engine.PlaylistCacheStatus.coldBuilt =>
        NativePlaylistCacheStatus.coldBuilt,
      native_engine.PlaylistCacheStatus.warmOpened =>
        NativePlaylistCacheStatus.warmOpened,
      native_engine.PlaylistCacheStatus.indexRebuiltFromCache =>
        NativePlaylistCacheStatus.indexRebuiltFromCache,
    },
    timings: NativePlaylistOpenTimings(
      totalMicros: result.timings.totalMicros.toInt(),
      sourceMapMicros: result.timings.sourceMapMicros.toInt(),
      indexBuildMicros: result.timings.indexBuildMicros.toInt(),
      firstPageMicros: result.timings.firstPageMicros.toInt(),
    ),
  );
}

NativeM3uChannelPage _mapPage(native_engine.M3uChannelPage page) {
  return NativeM3uChannelPage(
    channels: page.channels.map(_mapChannel).toList(growable: false),
    offset: page.offset,
    total: page.total,
    hasMore: page.hasMore,
  );
}

NativeM3uChannel _mapChannel(native_m3u.M3uChannel channel) {
  return NativeM3uChannel(
    name: channel.name,
    url: channel.url,
    logo: channel.logo,
    group: channel.group,
    tvgId: channel.tvgId,
    tvgName: channel.tvgName,
    language: channel.language,
    aliases: channel.aliases,
    country: channel.country,
    provider: channel.provider,
    tags: channel.tags,
  );
}
