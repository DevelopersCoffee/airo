import 'dart:io';

import 'package:airo_app/core/mind/mind_processing_queue.dart';
import 'package:airo_app/core/mind/mind_provider_overrides.dart';
import 'package:airo_app/main_mind.dart';
import 'package:airo_pro_bootstrap/airo_pro_bootstrap.dart' as pro_bootstrap;
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMindService extends Mock implements MindService {}

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

  test('mindMeetingProcessingOverrides restores an empty queue store', () async {
    final mindService = _MockMindService();

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
  });
}
