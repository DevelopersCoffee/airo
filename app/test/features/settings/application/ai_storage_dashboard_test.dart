import 'dart:io';

import 'package:airo_app/features/settings/application/ai_storage_dashboard.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const diskChannel = MethodChannel('com.airo.model_download');
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'airo_storage_dashboard_test',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
          if (methodCall.method == 'getApplicationDocumentsDirectory') {
            return tempDir.path;
          }
          if (methodCall.method == 'getTemporaryDirectory') {
            return path.join(tempDir.path, 'tmp');
          }
          return null;
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(diskChannel, (methodCall) async {
          if (methodCall.method == 'getFreeDiskSpace') {
            return 2 * 1024 * 1024 * 1024;
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(diskChannel, null);
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'builds aggregate local storage dashboard without exposing paths',
    () async {
      await File(path.join(tempDir.path, 'models', 'gemma.gguf'))
          .create(recursive: true)
          .then((file) => file.writeAsBytes(List.filled(4, 1)));
      await File(path.join(tempDir.path, 'meeting_audio', 'standup.m4a'))
          .create(recursive: true)
          .then((file) => file.writeAsBytes(List.filled(8, 1)));
      await File(
        path.join(tempDir.path, 'airo_money.db'),
      ).writeAsBytes(List.filled(16, 1));
      await File(path.join(tempDir.path, 'tmp', 'audio_cache', 'tts.wav'))
          .create(recursive: true)
          .then((file) => file.writeAsBytes(List.filled(32, 1)));

      final summary = await AIStorageDashboardService().loadSummary();

      expect(summary.categories, hasLength(6));
      expect(summary.category(AIStorageCategoryKind.installedModels).bytes, 4);
      expect(summary.category(AIStorageCategoryKind.meetingStorage).bytes, 8);
      expect(summary.category(AIStorageCategoryKind.databaseSize).bytes, 16);
      expect(summary.category(AIStorageCategoryKind.audioCache).bytes, 32);
      expect(
        summary.category(AIStorageCategoryKind.availableSpace).bytes,
        2 * 1024 * 1024 * 1024,
      );
      expect(summary.totalUsedBytes, 60);
      expect(summary.categories.map((category) => category.label), [
        'Installed models',
        'Meeting storage',
        'Embedding storage',
        'Database size',
        'Audio cache',
        'Available space',
      ]);
      expect(summary.toString(), isNot(contains(tempDir.path)));
    },
  );

  test('marks unavailable metrics without failing the dashboard', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(diskChannel, (methodCall) async {
          throw PlatformException(code: 'unavailable');
        });

    final summary = await AIStorageDashboardService().loadSummary();

    expect(
      summary.category(AIStorageCategoryKind.availableSpace).available,
      isFalse,
    );
    expect(summary.category(AIStorageCategoryKind.availableSpace).bytes, 0);
  });
}
