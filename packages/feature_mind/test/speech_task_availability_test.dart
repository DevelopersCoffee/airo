import 'dart:io';

import 'package:feature_mind/src/mind_service.dart' show MindUnavailable;
import 'package:feature_mind/src/models/model_provider.dart';
import 'package:feature_mind/src/speech_task_availability.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_bridges.dart';

class _FakeModelProvider implements ModelProvider {
  _FakeModelProvider({this.installed = true});

  final bool installed;

  @override
  Future<void> dispose() async {}

  @override
  bool get acquiresWithoutNetwork => true;

  @override
  Future<List<RequiredModel>> requiredModels() async => const [];

  @override
  Future<bool> isInstalled(Directory modelsDir) async => installed;

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async =>
      const [];

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) =>
      const Stream.empty();

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async => const [];
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('speech-availability');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('SpeechTaskAvailabilityChecker.speechToText', () {
    test('is available when the bridge loads and the model is installed', () async {
      final checker = SpeechTaskAvailabilityChecker(
        speechBridge: FakeMindSpeechBridge(),
        modelProvider: _FakeModelProvider(installed: true),
      );

      final result = await checker.speechToText(tempDir);

      expect(result.available, isTrue);
      expect(result.unavailableReason, isNull);
    });

    test('reports bridgeMissing when the native library fails to load', () async {
      final speech = FakeMindSpeechBridge()..loadLibraryError = StateError('no library');
      final checker = SpeechTaskAvailabilityChecker(
        speechBridge: speech,
        modelProvider: _FakeModelProvider(installed: true),
      );

      final result = await checker.speechToText(tempDir);

      expect(result.available, isFalse);
      expect(result.unavailableReason, MindUnavailable.bridgeMissing);
      expect(result.detail, contains('no library'));
    });

    test('reports modelsMissing without attempting to acquire anything', () async {
      var acquireCalls = 0;
      final provider = _AcquireTrackingModelProvider(
        installed: false,
        onAcquire: () => acquireCalls++,
      );
      final checker = SpeechTaskAvailabilityChecker(
        speechBridge: FakeMindSpeechBridge(),
        modelProvider: provider,
      );

      final result = await checker.speechToText(tempDir);

      expect(result.available, isFalse);
      expect(result.unavailableReason, MindUnavailable.modelsMissing);
      expect(acquireCalls, 0);
    });
  });

  group('SpeechTaskAvailabilityChecker.textToSpeech', () {
    test('is always unavailable, for a reason outside MindUnavailable', () {
      const checker = SpeechTaskAvailabilityChecker();

      final result = checker.textToSpeech();

      expect(result.available, isFalse);
      // Null, not one of MindUnavailable's cases: this is a permanent
      // product gap, not a startup failure -- see the class doc for why
      // conflating the two would misdescribe it.
      expect(result.unavailableReason, isNull);
      expect(result.detail, isNotEmpty);
    });
  });
}

class _AcquireTrackingModelProvider implements ModelProvider {
  _AcquireTrackingModelProvider({required this.installed, required this.onAcquire});

  final bool installed;
  final void Function() onAcquire;

  @override
  Future<void> dispose() async {}

  @override
  bool get acquiresWithoutNetwork => true;

  @override
  Future<List<RequiredModel>> requiredModels() async => const [];

  @override
  Future<bool> isInstalled(Directory modelsDir) async => installed;

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async =>
      const [];

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {
    onAcquire();
  }

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async => const [];
}
