import 'dart:io';

import 'package:airo_app/core/mind/mind_processing_queue.dart';
import 'package:airo_app/core/mind/mind_provider_overrides.dart';
import 'package:airo_app/main_mind.dart';
import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_ai/core_ai.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/src/bridges/mind_generation_bridge.dart';
import 'package:feature_mind/src/bridges/mind_speech_bridge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAudioRecorder extends Mock implements AudioRecorder {}

class _FakeSpeechBridge implements MindSpeechBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeGenerationBridge implements MindGenerationBridge {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeReadyModelProvider implements ModelProvider {
  @override
  bool get acquiresWithoutNetwork => true;

  @override
  Future<List<RequiredModel>> requiredModels() async => const [];

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async =>
      const [];

  @override
  Future<bool> isInstalled(Directory modelsDir) async => true;

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {}

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async => const [];

  @override
  Future<void> dispose() async {}
}

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProviderPlatform(this.basePath);

  final String basePath;

  @override
  Future<String?> getApplicationSupportPath() async => basePath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    SharedPreferences.setMockInitialValues({'speech_language_mode': 'auto'});
    tempDir = Directory.systemTemp.createTempSync('mind_shell_wiring_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
    'buildMindProviderOverrides wires prefs entitlements and module overrides',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final registry = buildMindModuleRegistry();
      final overrides = buildMindProviderOverrides(
        prefs: prefs,
        registry: registry,
      );

      expect(overrides.length, greaterThan(3));

      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(sharedPreferencesProvider), prefs);
      expect(
        container.read(mindEntitlementsProvider),
        pro_bootstrap.createEntitlements(),
      );
    },
  );

  test(
    'mindMeetingProcessingOverrides restores an empty queue store',
    () async {
      final mindService = MindService(
        recorder: _MockAudioRecorder(),
        modelProvider: _FakeReadyModelProvider(),
        speechBridge: _FakeSpeechBridge(),
        generationBridge: _FakeGenerationBridge(),
      );

      final container = ProviderContainer(
        overrides: mindMeetingProcessingOverrides(mindService),
      );
      addTearDown(container.dispose);

      final queue = await container.read(meetingProcessingQueueProvider.future);
      expect(queue, isA<MeetingProcessingQueue>());

      final queuePath = p.join(
        tempDir.path,
        'mind_recordings',
        'processing_queue.json',
      );
      expect(File(queuePath).existsSync(), isTrue);
    },
  );
}
