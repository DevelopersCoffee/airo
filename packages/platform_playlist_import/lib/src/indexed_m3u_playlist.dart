import 'package:core_native/core_native.dart';
import 'package:platform_channels/platform_channels.dart';

typedef NativePlaylistOpen =
    Future<NativePlaylistIndexOpenResult?> Function({
      required String sourcePath,
      required String cacheDirectory,
      int firstPageLimit,
    });
typedef NativePlaylistPage =
    Future<NativeM3uChannelPage?> Function({
      required String indexPath,
      required int offset,
      int limit,
    });
typedef NativePlaylistSearch =
    Future<NativeM3uChannelPage?> Function({
      required String indexPath,
      required String query,
      required int offset,
      int limit,
    });

class IndexedM3uPlaylistDescriptor {
  const IndexedM3uPlaylistDescriptor({
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

class IndexedM3uChannelPage {
  const IndexedM3uChannelPage({
    required this.channels,
    required this.offset,
    required this.total,
    required this.hasMore,
  });

  final List<IPTVChannel> channels;
  final int offset;
  final int total;
  final bool hasMore;
}

enum IndexedM3uPlaylistCacheStatus {
  coldBuilt,
  warmOpened,
  indexRebuiltFromCache,
}

class IndexedM3uPlaylistOpenResult {
  const IndexedM3uPlaylistOpenResult({
    required this.descriptor,
    required this.firstPage,
    required this.cacheStatus,
    required this.totalMicros,
    required this.firstPageMicros,
  });

  final IndexedM3uPlaylistDescriptor descriptor;
  final IndexedM3uChannelPage firstPage;
  final IndexedM3uPlaylistCacheStatus cacheStatus;
  final int totalMicros;
  final int firstPageMicros;
}

/// Paging adapter consumed by application providers. It never parses or
/// serializes playlist-sized payloads on the main isolate.
class IndexedM3uPlaylistService {
  const IndexedM3uPlaylistService({
    this.openNative = openPlaylistIndexNative,
    this.pageNative = pagePlaylistIndexNative,
    this.searchNative = searchPlaylistIndexNative,
  });

  final NativePlaylistOpen openNative;
  final NativePlaylistPage pageNative;
  final NativePlaylistSearch searchNative;

  Future<IndexedM3uPlaylistOpenResult?> open({
    required String sourcePath,
    required String cacheDirectory,
    int firstPageLimit = 50,
  }) async {
    final native = await openNative(
      sourcePath: sourcePath,
      cacheDirectory: cacheDirectory,
      firstPageLimit: firstPageLimit,
    );
    if (native == null) return null;
    return IndexedM3uPlaylistOpenResult(
      descriptor: IndexedM3uPlaylistDescriptor(
        indexPath: native.descriptor.indexPath,
        cachePath: native.descriptor.cachePath,
        totalChannels: native.descriptor.totalChannels,
        sourceSizeBytes: native.descriptor.sourceSizeBytes,
        sourceModifiedNanos: native.descriptor.sourceModifiedNanos,
      ),
      firstPage: _mapPage(native.firstPage),
      cacheStatus: switch (native.cacheStatus) {
        NativePlaylistCacheStatus.coldBuilt =>
          IndexedM3uPlaylistCacheStatus.coldBuilt,
        NativePlaylistCacheStatus.warmOpened =>
          IndexedM3uPlaylistCacheStatus.warmOpened,
        NativePlaylistCacheStatus.indexRebuiltFromCache =>
          IndexedM3uPlaylistCacheStatus.indexRebuiltFromCache,
      },
      totalMicros: native.timings.totalMicros,
      firstPageMicros: native.timings.firstPageMicros,
    );
  }

  Future<IndexedM3uChannelPage?> page({
    required IndexedM3uPlaylistDescriptor descriptor,
    required int offset,
    int limit = 50,
  }) async {
    final native = await pageNative(
      indexPath: descriptor.indexPath,
      offset: offset,
      limit: limit,
    );
    return native == null ? null : _mapPage(native);
  }

  Future<IndexedM3uChannelPage?> search({
    required IndexedM3uPlaylistDescriptor descriptor,
    required String query,
    int offset = 0,
    int limit = 50,
  }) async {
    final native = await searchNative(
      indexPath: descriptor.indexPath,
      query: query,
      offset: offset,
      limit: limit,
    );
    return native == null ? null : _mapPage(native);
  }
}

IndexedM3uChannelPage _mapPage(NativeM3uChannelPage page) {
  return IndexedM3uChannelPage(
    channels: page.channels.map(_mapChannel).toList(growable: false),
    offset: page.offset,
    total: page.total,
    hasMore: page.hasMore,
  );
}

IPTVChannel _mapChannel(NativeM3uChannel channel) {
  return IPTVChannel.fromM3U(
    name: channel.name,
    url: channel.url,
    logo: channel.logo,
    group: channel.group,
    tvgId: channel.tvgId,
    tvgName: channel.tvgName,
    language: channel.language,
  );
}
