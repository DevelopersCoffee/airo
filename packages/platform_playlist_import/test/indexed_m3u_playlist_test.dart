import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

void main() {
  group('IndexedM3uPlaylistService', () {
    test(
      'returns a first page without materializing the full playlist',
      () async {
        final calls = <String>[];
        final service = IndexedM3uPlaylistService(
          openNative:
              ({
                required sourcePath,
                required cacheDirectory,
                firstPageLimit = 50,
              }) async {
                calls.add('$sourcePath|$cacheDirectory|$firstPageLimit');
                return nativeOpenResult();
              },
        );

        final opened = await service.open(
          sourcePath: '/private/playlist.m3u',
          cacheDirectory: '/private/cache',
          firstPageLimit: 2,
        );

        expect(calls, ['/private/playlist.m3u|/private/cache|2']);
        expect(opened, isNotNull);
        expect(opened!.descriptor.totalChannels, 100000);
        expect(opened.firstPage.channels, hasLength(2));
        expect(opened.firstPage.channels.first.name, 'News One');
        expect(
          opened.firstPage.channels.first.streamUrl,
          'https://example.com/1',
        );
        expect(opened.firstPage.hasMore, isTrue);
        expect(opened.cacheStatus, IndexedM3uPlaylistCacheStatus.coldBuilt);
        expect(opened.totalMicros, 750000);
      },
    );

    test('pages and searches through the opaque index path', () async {
      final calls = <String>[];
      final service = IndexedM3uPlaylistService(
        pageNative: ({required indexPath, required offset, limit = 50}) async {
          calls.add('page:$indexPath:$offset:$limit');
          return nativePage(offset: offset, total: 100000);
        },
        searchNative:
            ({
              required indexPath,
              required query,
              required offset,
              limit = 50,
            }) async {
              calls.add('search:$indexPath:$query:$offset:$limit');
              return nativePage(offset: offset, total: 2, hasMore: false);
            },
      );
      const descriptor = IndexedM3uPlaylistDescriptor(
        indexPath: '/private/cache/playlist-v2.sqlite',
        cachePath: '/private/cache/playlist-v2.cache',
        totalChannels: 100000,
        sourceSizeBytes: 20000000,
        sourceModifiedNanos: 42,
      );

      final page = await service.page(
        descriptor: descriptor,
        offset: 50,
        limit: 25,
      );
      final search = await service.search(
        descriptor: descriptor,
        query: 'news',
        limit: 10,
      );

      expect(page?.offset, 50);
      expect(search?.total, 2);
      expect(calls, [
        'page:/private/cache/playlist-v2.sqlite:50:25',
        'search:/private/cache/playlist-v2.sqlite:news:0:10',
      ]);
    });

    test('returns null so callers can select worker fallback', () async {
      final service = IndexedM3uPlaylistService(
        openNative:
            ({
              required sourcePath,
              required cacheDirectory,
              firstPageLimit = 50,
            }) async => null,
        pageNative: ({required indexPath, required offset, limit = 50}) async =>
            null,
        searchNative:
            ({
              required indexPath,
              required query,
              required offset,
              limit = 50,
            }) async => null,
      );
      const descriptor = IndexedM3uPlaylistDescriptor(
        indexPath: '/index',
        cachePath: '/cache',
        totalChannels: 0,
        sourceSizeBytes: 0,
        sourceModifiedNanos: 0,
      );

      expect(
        await service.open(sourcePath: '/source', cacheDirectory: '/cache'),
        isNull,
      );
      expect(await service.page(descriptor: descriptor, offset: 0), isNull);
      expect(
        await service.search(descriptor: descriptor, query: 'news'),
        isNull,
      );
    });
  });
}

NativePlaylistIndexOpenResult nativeOpenResult() {
  return NativePlaylistIndexOpenResult(
    descriptor: const NativePlaylistIndexDescriptor(
      indexPath: '/private/cache/playlist-v2.sqlite',
      cachePath: '/private/cache/playlist-v2.cache',
      totalChannels: 100000,
      sourceSizeBytes: 20000000,
      sourceModifiedNanos: 42,
    ),
    firstPage: nativePage(offset: 0, total: 100000),
    parseStats: const NativeM3uParseStats(
      parsedCount: 100000,
      skippedCount: 0,
      malformedCount: 0,
      elapsedMillis: 700,
    ),
    cacheStatus: NativePlaylistCacheStatus.coldBuilt,
    timings: const NativePlaylistOpenTimings(
      totalMicros: 750000,
      sourceMapMicros: 100,
      indexBuildMicros: 700000,
      firstPageMicros: 1000,
    ),
  );
}

NativeM3uChannelPage nativePage({
  required int offset,
  required int total,
  bool hasMore = true,
}) {
  return NativeM3uChannelPage(
    channels: const [
      NativeM3uChannel(
        name: 'News One',
        url: 'https://example.com/1',
        group: 'News',
        language: 'en',
      ),
      NativeM3uChannel(
        name: 'Sports One',
        url: 'https://example.com/2',
        group: 'Sports',
        language: 'en',
      ),
    ],
    offset: offset,
    total: total,
    hasMore: hasMore,
  );
}
