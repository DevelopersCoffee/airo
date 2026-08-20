import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _model(
  String id, {
  List<ModelCapability> capabilities = const [ModelCapability.chat],
  List<ModelModality> modalities = const [ModelModality.text],
  bool downloaded = false,
  int size = 1000,
  int? parameters,
  List<String> languages = const ['en'],
  String? downloadUrl = 'https://example.test/model',
  InferenceRuntime? runtime,
  ModelTask? task,
  PlatformSupport? platformSupport,
  int contextLength = 2048,
}) => OfflineModelInfo(
  id: id,
  name: id,
  family: ModelFamily.other,
  fileSizeBytes: size,
  filePath: downloaded ? '/tmp/$id' : null,
  downloadUrl: downloadUrl,
  capabilities: capabilities,
  modalities: modalities,
  languages: languages,
  parameterCount: parameters,
  runtime: runtime,
  task: task,
  platformSupport: platformSupport,
  contextLength: contextLength,
  credibility: ModelCredibility.official,
);

void main() {
  const query = IntelligenceQuery();

  group('IntelligenceQuery.capabilitiesPresent', () {
    test('omits capabilities with no installable model', () {
      final catalog = [
        _model('chat-only', capabilities: const [ModelCapability.chat]),
        _model(
          'tokenizer',
          capabilities: const [],
          modalities: const [],
          downloadUrl: 'https://example.test/tok',
        ),
      ];

      expect(query.capabilitiesPresent(catalog), [ModelCapability.chat]);
    });

    test('does not invent vision when no vision model exists', () {
      final catalog = [
        _model('text', capabilities: const [ModelCapability.chat]),
      ];

      expect(
        query.capabilitiesPresent(catalog),
        isNot(contains(ModelCapability.imageUnderstanding)),
      );
    });

    test('includes transcription from speech metadata, not model ids', () {
      final catalog = [
        _model(
          'speech',
          capabilities: const [ModelCapability.audioUnderstanding],
          modalities: const [ModelModality.audio],
          runtime: InferenceRuntime.whisper,
          task: ModelTask.speechToText,
        ),
      ];

      expect(
        query.capabilitiesPresent(catalog),
        contains(ModelCapability.audioUnderstanding),
      );
    });
  });

  group('IntelligenceQuery.select', () {
    test('prefers an installed model that serves the capability', () {
      final installed = _model('small-chat', downloaded: true, size: 500);
      final larger = _model(
        'large-chat',
        size: 4_000_000_000,
        parameters: 7_000_000_000,
      );

      final selection = query.select(
        capability: ModelCapability.chat,
        catalog: [larger, installed],
      );

      expect(selection.model?.id, 'small-chat');
      expect(selection.ready, isTrue);
      expect(selection.why?.automatic, isTrue);
    });

    test('override wins over automatic ranking', () {
      final first = _model('first', downloaded: true);
      final second = _model('second', downloaded: true);

      final selection = query.select(
        capability: ModelCapability.chat,
        catalog: [first, second],
        overrideModelId: 'second',
      );

      expect(selection.model?.id, 'second');
      expect(selection.why?.automatic, isFalse);
      expect(
        selection.why?.reasons.map((reason) => reason.code),
        contains(WhySelectedCode.override),
      );
    });

    test('compact bias prefers the smaller speech model', () {
      final tiny = _model(
        'tiny-speech',
        capabilities: const [ModelCapability.audioUnderstanding],
        modalities: const [ModelModality.audio],
        runtime: InferenceRuntime.whisper,
        task: ModelTask.speechToText,
        size: 70_000_000,
        downloaded: true,
      );
      final small = _model(
        'small-speech',
        capabilities: const [ModelCapability.audioUnderstanding],
        modalities: const [ModelModality.audio],
        runtime: InferenceRuntime.whisper,
        task: ModelTask.speechToText,
        size: 480_000_000,
        downloaded: true,
      );

      final selection = query.select(
        capability: ModelCapability.audioUnderstanding,
        catalog: [small, tiny],
        constraints: const IntelligenceConstraints(
          sizeBias: IntelligenceSizeBias.compact,
        ),
      );

      expect(selection.model?.id, 'tiny-speech');
    });

    test('quality bias prefers the larger speech model when both fit', () {
      final tiny = _model(
        'tiny-speech',
        capabilities: const [ModelCapability.audioUnderstanding],
        modalities: const [ModelModality.audio],
        runtime: InferenceRuntime.whisper,
        task: ModelTask.speechToText,
        size: 70_000_000,
        downloaded: true,
      );
      final small = _model(
        'small-speech',
        capabilities: const [ModelCapability.audioUnderstanding],
        modalities: const [ModelModality.audio],
        runtime: InferenceRuntime.whisper,
        task: ModelTask.speechToText,
        size: 480_000_000,
        parameters: 244_000_000,
        downloaded: true,
      );

      final selection = query.select(
        capability: ModelCapability.audioUnderstanding,
        catalog: [tiny, small],
        constraints: const IntelligenceConstraints(
          sizeBias: IntelligenceSizeBias.quality,
        ),
      );

      expect(selection.model?.id, 'small-speech');
    });

    test('hides android-only packages from a non-matching platform', () {
      final androidOnly = _model(
        'android-vision',
        capabilities: const [ModelCapability.imageUnderstanding],
        modalities: const [ModelModality.image],
        platformSupport: PlatformSupport.androidOnly(),
      );

      final present = query.capabilitiesPresent(
        [androidOnly],
        constraints: const IntelligenceConstraints(
          requireCurrentPlatform: true,
        ),
      );

      if (androidOnly.isRunnableOnCurrentPlatform) {
        expect(present, contains(ModelCapability.imageUnderstanding));
      } else {
        expect(present, isEmpty);
      }
    });
  });

  group('IntelligenceQuery.badgesFor', () {
    test('returns modality and capability badges, not family names', () {
      final model = _model(
        'qwen-chat',
        capabilities: const [
          ModelCapability.chat,
          ModelCapability.meetingSummarization,
        ],
      );

      expect(query.badgesFor(model), containsAll(['TEXT', 'CHAT', 'SUMMARY']));
      expect(query.badgesFor(model).join(), isNot(contains('Qwen')));
    });
  });
}
