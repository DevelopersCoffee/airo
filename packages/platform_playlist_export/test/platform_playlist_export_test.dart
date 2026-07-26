import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  group('PlaylistExportRequest', () {
    test('builds a sanitized filename from playlist title and format', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.m3u,
        playlistId: 'sports-01',
        playlistTitle: 'Sports & News / 24x7',
      );

      expect(request.suggestedFileName(), 'Sports_News_24x7.m3u');
    });

    test('falls back to a stable filename when title normalizes to empty', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'empty-01',
        playlistTitle: '***',
      );

      expect(request.suggestedFileName(), 'playlist_export.json');
    });

    test('serializes request metadata for downstream exporters', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'kids',
        playlistTitle: 'Kids',
        includeGroups: false,
        includeEpgMetadata: true,
      );

      expect(request.toMap(), <String, Object>{
        'format': 'json',
        'playlistId': 'kids',
        'playlistTitle': 'Kids',
        'includeGroups': false,
        'includeEpgMetadata': true,
        'suggestedFileName': 'Kids.json',
      });
    });
  });

  group('PlaylistExportResult', () {
    test('exposes derived media type and file name from request', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.m3u,
        playlistId: 'news',
        playlistTitle: 'Daily News',
      );
      const result = PlaylistExportResult(
        request: request,
        contents: '#EXTM3U',
      );

      expect(result.mediaType, 'audio/x-mpegurl');
      expect(result.suggestedFileName, 'Daily_News.m3u');
    });

    test('serializes the export result envelope', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'all',
        playlistTitle: 'All Channels',
      );
      const result = PlaylistExportResult(
        request: request,
        contents: '{"channels":[]}',
      );

      expect(result.toMap(), <String, Object>{
        'request': <String, Object>{
          'format': 'json',
          'playlistId': 'all',
          'playlistTitle': 'All Channels',
          'includeGroups': true,
          'includeEpgMetadata': false,
          'suggestedFileName': 'All_Channels.json',
        },
        'mediaType': 'application/json',
        'suggestedFileName': 'All_Channels.json',
        'contents': '{"channels":[]}',
      });
    });
  });

  group('AiroBackupService', () {
    final snapshot = AiroBackupSnapshot(
      playlistSources: const [
        AiroBackupSource(
          id: 'playlist',
          url: 'https://example.com/list.m3u',
          label: 'Main',
        ),
      ],
      favorites: const [
        AiroBackupFavorite(
          channelId: 'channel-a',
          name: 'Channel A',
          url: 'https://example.com/a.m3u8',
          group: 'News',
        ),
      ],
      epgSources: const [
        AiroBackupSource(
          id: 'guide',
          url: 'https://example.com/guide.xml',
          label: 'Guide',
        ),
      ],
      settings: const {'captions': 'on'},
    );

    test('export wipe import round trip restores identical values', () async {
      final store = _FakeBackupStore(snapshot);
      final service = AiroBackupService(
        store: store,
        recognizedSettingKeys: const {'captions'},
      );
      final archive = await service.export();
      store.value = AiroBackupSnapshot(
        playlistSources: const [],
        favorites: const [],
        epgSources: const [],
        settings: const {},
      );

      final preview = await service.previewImport(archive);
      await service.apply(preview);

      expect(store.atomicWrites, 1);
      expect(store.value.toMap(), snapshot.toMap());
    });

    test('reimport dedupes source URLs and unions favorites', () async {
      final store = _FakeBackupStore(snapshot);
      final incoming = AiroBackupSnapshot(
        playlistSources: const [
          AiroBackupSource(
            id: 'playlist',
            url: 'HTTPS://EXAMPLE.COM/list.m3u',
            label: 'Main',
          ),
        ],
        favorites: const [
          AiroBackupFavorite(
            channelId: 'channel-b',
            name: 'Channel B',
            url: 'https://example.com/b.m3u8',
          ),
        ],
        epgSources: const [],
        settings: const {'unknown': 'ignored'},
      );
      final service = AiroBackupService(
        store: store,
        recognizedSettingKeys: const {'captions'},
      );

      final preview = await service.previewImport(
        await const AiroBackupCodec().encode(incoming),
      );

      expect(preview.playlistAdditions, 0);
      expect(preview.favoriteAdditions, 1);
      expect(preview.settingChanges, 0);
    });

    test('malformed and old archives never reach atomic apply', () async {
      final store = _FakeBackupStore(snapshot);
      final service = AiroBackupService(store: store);

      await expectLater(
        service.previewImport('{bad'),
        throwsA(
          isA<AiroBackupException>().having(
            (error) => error.code,
            'code',
            AiroBackupRejection.malformed,
          ),
        ),
      );
      await expectLater(
        service.previewImport('{"schema":"airo.tv.backup","version":0}'),
        throwsA(
          isA<AiroBackupException>().having(
            (error) => error.code,
            'code',
            AiroBackupRejection.unsupportedSchema,
          ),
        ),
      );
      expect(store.atomicWrites, 0);
    });

    test('favorites M3U is stable and strips injected line breaks', () {
      final output = exportFavoritesM3u([
        const AiroBackupFavorite(
          channelId: 'b',
          name: 'B',
          url: 'https://example.com/b',
        ),
        const AiroBackupFavorite(
          channelId: 'a',
          name: 'A\nInjected',
          url: 'https://example.com/a',
          group: 'News',
        ),
      ]);

      expect(output, startsWith('#EXTM3U\n#EXTINF:-1 tvg-id="a"'));
      expect(output, contains(',A Injected\nhttps://example.com/a\n'));
    });

    test('conflicting source ids are rejected before apply', () async {
      final conflicting = AiroBackupSnapshot(
        playlistSources: const [
          AiroBackupSource(
            id: 'same',
            url: 'https://example.com/one',
            label: 'One',
          ),
          AiroBackupSource(
            id: 'same',
            url: 'https://example.com/two',
            label: 'Two',
          ),
        ],
        favorites: const [],
        epgSources: const [],
        settings: const {},
      );

      await expectLater(
        const AiroBackupCodec().encode(conflicting),
        throwsA(
          isA<AiroBackupException>().having(
            (error) => error.code,
            'code',
            AiroBackupRejection.conflictingRecord,
          ),
        ),
      );
    });

    test('large production archive round trips through worker codec', () async {
      final large = AiroBackupSnapshot(
        playlistSources: [
          for (var index = 0; index < 700; index++)
            AiroBackupSource(
              id: 'source-$index',
              url: 'https://example.com/$index/list.m3u',
              label: 'Source ${List.filled(60, 'x').join()} $index',
            ),
        ],
        favorites: const [],
        epgSources: const [],
        settings: const {},
      );

      final encoded = await const AiroBackupCodec().encode(large);
      final decoded = await const AiroBackupCodec().decode(encoded);

      expect(encoded.length, greaterThan(kAiroBackupWorkerThresholdBytes));
      expect(decoded.toMap(), large.toMap());
    });
  });
}

class _FakeBackupStore implements AiroBackupStateStore {
  _FakeBackupStore(this.value);

  AiroBackupSnapshot value;
  int atomicWrites = 0;

  @override
  Future<AiroBackupSnapshot> read() async => value;

  @override
  Future<void> replaceAtomically(AiroBackupSnapshot snapshot) async {
    atomicWrites++;
    value = snapshot;
  }
}
