import 'dart:convert';
import 'dart:io';

import 'package:airo_app/core/portability/airo_backup_service.dart';
import 'package:airo_app/features/agent_chat/data/services/chat_history_store.dart';
import 'package:airo_app/features/settings/presentation/screens/airo_portability_screen.dart';
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
