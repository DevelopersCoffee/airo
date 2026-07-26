import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  testWidgets('import presents preview and applies only after confirmation', (
    tester,
  ) async {
    final current = AiroBackupSnapshot(
      playlistSources: const [],
      favorites: const [],
      epgSources: const [],
      settings: const {},
    );
    final incoming = AiroBackupSnapshot(
      playlistSources: const [
        AiroBackupSource(
          id: 'main',
          url: 'https://example.com/main.m3u',
          label: 'Main',
        ),
      ],
      favorites: const [],
      epgSources: const [],
      settings: const {},
    );
    final state = _FakeStateStore(current);
    final service = AiroBackupService(store: state);
    final gateway = _FakeDocumentGateway(
      AiroBackupDocument(
        fileName: 'backup.json',
        mediaType: 'application/json',
        contents: await const AiroBackupCodec().encode(incoming),
      ),
    );
    final controller = AiroBackupDocumentController(
      service: service,
      documents: gateway,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvBackupServiceProvider.overrideWithValue(service),
          iptvBackupDocumentControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: Scaffold(body: BackupRestoreSection())),
      ),
    );

    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('backup-import-button')))
          .label,
      contains('Import'),
    );
    await tester.tap(find.byKey(const ValueKey('backup-import-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.byKey(const ValueKey('backup-import-preview-dialog')),
      findsOne,
    );
    expect(find.textContaining('1 playlist sources'), findsOne);
    expect(state.atomicWrites, 0);

    await tester.tap(
      find.byKey(const ValueKey('backup-import-confirm-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(state.atomicWrites, 1);
    expect(state.value.playlistSources.single.id, 'main');
    expect(find.text('Backup imported successfully.'), findsOne);
  });

  testWidgets('picker cancellation leaves state unchanged', (tester) async {
    final state = _FakeStateStore(
      AiroBackupSnapshot(
        playlistSources: const [],
        favorites: const [],
        epgSources: const [],
        settings: const {},
      ),
    );
    final service = AiroBackupService(store: state);
    final controller = AiroBackupDocumentController(
      service: service,
      documents: _FakeDocumentGateway(null),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvBackupServiceProvider.overrideWithValue(service),
          iptvBackupDocumentControllerProvider.overrideWithValue(controller),
        ],
        child: const MaterialApp(home: Scaffold(body: BackupRestoreSection())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('backup-import-button')));
    await tester.pumpAndSettle();

    expect(state.atomicWrites, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('favorites overflow shares a portable M3U document', (
    tester,
  ) async {
    final gateway = _FakeDocumentGateway(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          favoriteChannelsProvider.overrideWith(
            (ref) async => const [
              IPTVChannel(
                id: 'news',
                name: 'News',
                streamUrl: 'https://example.com/news.m3u8',
                group: 'News',
              ),
            ],
          ),
          iptvBackupDocumentGatewayProvider.overrideWithValue(gateway),
        ],
        child: const MaterialApp(home: Scaffold(body: FavoritesBackupMenu())),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('favorites-backup-overflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share favorites as M3U'));
    await tester.pumpAndSettle();

    expect(gateway.shared.single.fileName, 'airo_tv_favorites.m3u');
    expect(gateway.shared.single.contents, contains('#EXTM3U'));
    expect(gateway.shared.single.contents, contains('tvg-id="news"'));
  });
}

class _FakeStateStore implements AiroBackupStateStore {
  _FakeStateStore(this.value);

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

class _FakeDocumentGateway implements AiroBackupDocumentGateway {
  _FakeDocumentGateway(this.document);

  final AiroBackupDocument? document;
  final List<AiroBackupDocument> shared = [];

  @override
  Future<AiroBackupDocument?> pick() async => document;

  @override
  Future<void> save(AiroBackupDocument document) async {}

  @override
  Future<void> share(AiroBackupDocument document) async {
    shared.add(document);
  }
}
