import 'dart:convert';
import 'dart:io';

import 'package:airo_app/core/portability/airo_backup_service.dart';
import 'package:airo_app/features/settings/presentation/screens/airo_portability_screen.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('renders encrypted backup and LAN sync controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AiroPortabilityScreen()));

    expect(find.text('Airo Mind Portability'), findsOneWidget);
    expect(find.text('Encrypted export and import'), findsOneWidget);
    expect(find.text('Backup passphrase'), findsOneWidget);
    expect(find.text('Export encrypted backup'), findsOneWidget);
    expect(find.text('Verify and import backup'), findsOneWidget);
    expect(find.text('Encrypted local LAN sync'), findsOneWidget);
    expect(find.text('Create LAN share'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Import from LAN share'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('LAN share URL'), findsOneWidget);
    expect(find.text('Import from LAN share'), findsOneWidget);
  });

  testWidgets('reports an invalid LAN share URL without leaving the screen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AiroPortabilityScreen()));

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    await tester.scrollUntilVisible(
      find.text('Import from LAN share'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField).last, 'ftp://not-a-share');
    await tester.ensureVisible(find.text('Import from LAN share'));
    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Import from LAN share'),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('LAN import failed:', skipOffstage: false),
      findsOneWidget,
    );
    expect(find.text('Airo Mind Portability'), findsOneWidget);
  });

  testWidgets('exports an encrypted backup through the injected share path', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'airo-portability-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    String? sharedPath;

    await tester.pumpWidget(
      MaterialApp(
        home: AiroPortabilityScreen(
          getDocumentsDirectory: () async => directory,
          shareExportPath: (path) async => sharedPath = path,
          backupService: _FastBackupService(),
          buildPayload: () async => const {
            'scope': 'airo-mind',
            'schemaVersion': 1,
            'chatHistory': [],
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    await tester.ensureVisible(find.text('Export encrypted backup'));
    await tester.tap(find.text('Export encrypted backup'));
    await _pumpAsyncWork(tester);

    expect(sharedPath, isNotNull);
    expect(File(sharedPath!).existsSync(), isTrue);
    expect(
      find.text(
        'Encrypted backup created and ready to share.',
        skipOffstage: false,
      ),
      findsOneWidget,
    );
  });

  testWidgets('export payload preserves model metadata and chat history', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'airo-portability-payload-export-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final backupService = _RecordingBackupService();

    await tester.pumpWidget(
      MaterialApp(
        home: AiroPortabilityScreen(
          getDocumentsDirectory: () async => directory,
          shareExportPath: (_) async {},
          backupService: backupService,
          buildPayload: () async => {
            'scope': 'airo-mind',
            'schemaVersion': 1,
            'modelCatalogIds': ['gemma-4-e2b-it-litertlm'],
            'chatHistory': [
              {'id': 'chat-default', 'title': 'Default export'},
            ],
            'privacy': 'local-first',
          },
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    final exportButton = find.widgetWithText(
      FilledButton,
      'Export encrypted backup',
    );
    final result =
        (tester.widget<FilledButton>(exportButton).onPressed as dynamic)
            ?.call();
    if (result is Future<void>) await result;
    await _pumpAsyncWork(tester);

    final payload = backupService.lastPayload;
    expect(payload, isNotNull);
    expect(payload?['scope'], 'airo-mind');
    expect(payload?['privacy'], 'local-first');
    expect(payload?['modelCatalogIds'], isA<List>());
    expect(payload?['chatHistory'], isA<List>());
    expect(
      (payload?['chatHistory'] as List).single,
      containsPair('id', 'chat-default'),
    );
  });

  testWidgets(
    'default export payload includes bundled models without weights',
    (tester) async {
      final directory = Directory.systemTemp.createTempSync(
        'airo-portability-default-export-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final backupService = _RecordingBackupService();

      await tester.pumpWidget(
        MaterialApp(
          home: AiroPortabilityScreen(
            getDocumentsDirectory: () async => directory,
            shareExportPath: (_) async {},
            backupService: backupService,
            encodePayload: (payload) async => jsonEncode(payload),
          ),
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        'release-passphrase',
      );
      final exportButton = find.widgetWithText(
        FilledButton,
        'Export encrypted backup',
      );
      final result =
          (tester.widget<FilledButton>(exportButton).onPressed as dynamic)
              ?.call();
      if (result is Future<void>) await result;
      await _pumpAsyncWork(tester);

      final payload = backupService.lastPayload;
      expect(payload?['scope'], 'airo-mind');
      expect(payload?['privacy'], 'local-first');
      expect(payload?['note'], contains('model weights are not copied'));
      expect(payload?['modelCatalogIds'], isA<List>());
      expect(payload?['chatHistory'], isEmpty);
    },
  );

  testWidgets('imports encrypted chat history from an injected backup file', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'airo-portability-import-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final backup = File('${directory.path}/restore.airobackup');
    backup.writeAsStringSync('encrypted-backup', flush: true);

    await tester.pumpWidget(
      MaterialApp(
        home: AiroPortabilityScreen(
          pickBackupPath: () async => backup.path,
          readBackupContent: (_) async => 'encrypted-backup',
          backupService: _FastBackupService(),
          encodePayload: (payload) async => jsonEncode(payload),
          encodeChatHistory: (entries, {required schemaVersion}) async =>
              jsonEncode({'schemaVersion': schemaVersion, 'entries': entries}),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    final importButton = find.widgetWithText(
      OutlinedButton,
      'Verify and import backup',
    );
    await tester.ensureVisible(importButton);
    final result =
        (tester.widget<OutlinedButton>(importButton).onPressed as dynamic)
            ?.call();
    if (result is Future<void>) await result;
    await _pumpAsyncWork(tester);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(ChatHistoryStore.storageKey), contains('chat-1'));
    expect(
      find.textContaining('Backup verified and restored', skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets('export and import failures show actionable status text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AiroPortabilityScreen(
          getDocumentsDirectory: () async => throw StateError('disk full'),
          backupService: _FastBackupService(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    await tester.tap(find.text('Export encrypted backup'));
    await _pumpAsyncWork(tester);

    expect(
      find.textContaining('Export failed:', skipOffstage: false),
      findsOneWidget,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AiroPortabilityScreen(
          pickBackupPath: () async => '/tmp/missing.airobackup',
          readBackupContent: (_) async => 'bad-backup',
          backupService: _FailingBackupService(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'release-passphrase');
    final importButton = find.widgetWithText(
      OutlinedButton,
      'Verify and import backup',
    );
    await tester.ensureVisible(importButton);
    final result =
        (tester.widget<OutlinedButton>(importButton).onPressed as dynamic)
            ?.call();
    if (result is Future<void>) await result;
    await _pumpAsyncWork(tester);

    expect(
      find.textContaining('Import failed:', skipOffstage: false),
      findsOneWidget,
    );
  });
}

Future<void> _pumpAsyncWork(WidgetTester tester) async {
  for (var i = 0; i < 6; i += 1) {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _FastBackupService extends AiroBackupService {
  @override
  Future<File> writeExport({
    required Directory directory,
    required Map<String, Object?> payload,
    required String passphrase,
  }) {
    if (!directory.existsSync()) directory.createSync(recursive: true);
    final file = File('${directory.path}/fast.airobackup');
    file.writeAsStringSync(
      'encrypted:$passphrase:${payload['scope']}',
      flush: true,
    );
    return Future<File>.value(file);
  }

  @override
  Future<String> encrypt(
    Map<String, Object?> payload,
    String passphrase,
  ) async {
    return 'encrypted:$passphrase:${payload['scope']}';
  }

  @override
  Future<Map<String, Object?>> decrypt(
    String encoded,
    String passphrase,
  ) async {
    return {
      'scope': 'airo-mind',
      'schemaVersion': 1,
      'chatHistory': [
        {'id': 'chat-1', 'title': 'Release check'},
      ],
    };
  }
}

class _FailingBackupService extends AiroBackupService {
  @override
  Future<Map<String, Object?>> decrypt(
    String encoded,
    String passphrase,
  ) async {
    throw StateError('cannot decrypt');
  }
}

class _RecordingBackupService extends _FastBackupService {
  Map<String, Object?>? lastPayload;

  @override
  Future<File> writeExport({
    required Directory directory,
    required Map<String, Object?> payload,
    required String passphrase,
  }) {
    lastPayload = payload;
    return super.writeExport(
      directory: directory,
      payload: payload,
      passphrase: passphrase,
    );
  }
}
