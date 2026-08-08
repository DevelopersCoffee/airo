import 'dart:async';
import 'dart:io';

import 'package:feature_mind/src/mind_home_screen.dart';
import 'package:feature_mind/src/mind_service.dart';
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';

import 'support/fake_bridges.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  FakePathProviderPlatform(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

/// A provider whose bytes cost network — the production shape (#1554) — with
/// the acquisition scripted so a test can hold it half-finished.
class FakeDownloadProvider implements ModelProvider {
  @override
  Future<void> dispose() async {}

  FakeDownloadProvider({this.failures = const []});

  static const model = RequiredModel(
    fileName: 'ggml-tiny.en.bin',
    sizeBytes: 77704715,
    sha256: 'deadbeef',
  );

  /// Names reported by the final [ModelAcquisitionDone]. Non-empty is the
  /// failure path.
  final List<String> failures;

  var installed = false;
  var acquireCalls = 0;
  final events = StreamController<ModelAcquisitionEvent>.broadcast();

  @override
  bool get acquiresWithoutNetwork => false;

  @override
  Future<List<RequiredModel>> requiredModels() async => const [model];

  @override
  Future<bool> isInstalled(Directory modelsDir) async => installed;

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async =>
      installed ? const [] : const [model];

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) {
    acquireCalls++;
    return events.stream;
  }

  /// Ends the acquisition the way the real provider does.
  Future<void> finish() async {
    installed = failures.isEmpty;
    events.add(ModelAcquisitionDone(failures));
    await events.close();
  }

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late FakeMindSpeechBridge speech;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mind_acquisition_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
    speech = FakeMindSpeechBridge();
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  MindService serviceFor(ModelProvider provider) => MindService(
    recorder: MockAudioRecorder(),
    modelProvider: provider,
    speechBridge: speech,
    generationBridge: FakeMindGenerationBridge(),
  );

  test(
    'initialize does not spend the network by itself: it reports the missing '
    'models and leaves acquiring to the user',
    () async {
      final provider = FakeDownloadProvider();
      final status = await serviceFor(provider).initialize();

      expect(provider.acquireCalls, 0);
      expect(status.unavailable, MindUnavailable.modelsMissing);
      expect(status.detail, contains('ggml-tiny.en.bin'));
    },
  );

  test('a provider that costs no network still installs unprompted', () async {
    final provider = FakeDownloadProvider()..installed = false;
    // Bundled assets: the copy is local, so `initialize` runs it.
    final service = serviceFor(_LocalProvider(provider));

    await service.initialize();

    expect(provider.acquireCalls, 1);
  });

  testWidgets('the blocker offers the download, with its size', (tester) async {
    final provider = FakeDownloadProvider();
    await tester.pumpWidget(
      MaterialApp(home: MindHomeScreen(service: serviceFor(provider))),
    );
    await tester.pumpAndSettle();

    // 77,704,715 bytes rounds to 78 MB.
    expect(find.text('Download models (~78 MB)'), findsOneWidget);
    expect(find.textContaining('Wi-Fi'), findsOneWidget);
  });

  testWidgets('tapping download streams per-file progress', (tester) async {
    final provider = FakeDownloadProvider();
    await tester.pumpWidget(
      MaterialApp(home: MindHomeScreen(service: serviceFor(provider))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download models (~78 MB)'));
    await tester.pump();
    expect(provider.acquireCalls, 1);

    provider.events.add(
      const ModelAcquisitionProgress('ggml-tiny.en.bin', 38852357, 77704715),
    );
    await tester.pump();

    expect(find.text('ggml-tiny.en.bin — 39 MB of 78 MB'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('a successful download starts the app', (tester) async {
    final provider = FakeDownloadProvider();
    await tester.pumpWidget(
      MaterialApp(home: MindHomeScreen(service: serviceFor(provider))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download models (~78 MB)'));
    await tester.pump();
    await provider.finish();
    await tester.pumpAndSettle();

    // The library, not the blocker: startup ran again and found the models.
    expect(find.text('No meetings yet. Press Record to start one.'), findsOne);
    expect(find.text('Record'), findsOneWidget);
  });

  testWidgets('a failed download names the file and offers a retry', (
    tester,
  ) async {
    final provider = FakeDownloadProvider(failures: const ['ggml-tiny.en.bin']);
    await tester.pumpWidget(
      MaterialApp(home: MindHomeScreen(service: serviceFor(provider))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Download models (~78 MB)'));
    await tester.pump();
    await provider.finish();
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Could not download ggml-tiny.en.bin'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });
}

/// The same scripted acquisition, declared as costing no network — the
/// bundled-asset case, which `initialize` is allowed to run on its own.
class _LocalProvider implements ModelProvider {
  @override
  Future<void> dispose() async {}

  _LocalProvider(this._inner);

  final FakeDownloadProvider _inner;

  @override
  bool get acquiresWithoutNetwork => true;

  @override
  Future<List<RequiredModel>> requiredModels() => _inner.requiredModels();

  @override
  Future<bool> isInstalled(Directory modelsDir) =>
      _inner.isInstalled(modelsDir);

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) =>
      _inner.missingModels(modelsDir);

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) {
    _inner.acquireCalls++;
    return Stream.value(const ModelAcquisitionDone([]));
  }

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) =>
      _inner.verify(modelsDir);
}
