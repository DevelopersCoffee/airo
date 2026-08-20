import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/intelligence/ai_profile.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineModelInfo _model(
  String id, {
  List<ModelCapability> capabilities = const [ModelCapability.chat],
  List<ModelModality> modalities = const [ModelModality.text],
  bool downloaded = false,
  String? downloadUrl = 'https://example.test/model',
  InferenceRuntime? runtime,
  ModelTask? task,
  PlatformSupport? platformSupport,
}) => OfflineModelInfo(
  id: id,
  name: id,
  family: ModelFamily.other,
  fileSizeBytes: 1000,
  filePath: downloaded ? '/tmp/$id' : null,
  downloadUrl: downloadUrl,
  capabilities: capabilities,
  modalities: modalities,
  runtime: runtime,
  task: task,
  platformSupport: platformSupport,
);

void main() {
  const resolver = AiProfileResolver();

  test('hides Vision when no installable vision model exists', () {
    final catalog = [_model('chat-only')];

    final visible = resolver.visibleProfiles(catalog);

    expect(
      visible.map((profile) => profile.id),
      isNot(contains(AiProfileId.imageAssistant)),
    );
    expect(
      visible.map((profile) => profile.id),
      contains(AiProfileId.generalChat),
    );
  });

  test('shows Scribe when speech metadata is present, not from model ids', () {
    final catalog = [
      _model(
        'speech',
        capabilities: const [ModelCapability.audioUnderstanding],
        modalities: const [ModelModality.audio],
        runtime: InferenceRuntime.whisper,
        task: ModelTask.speechToText,
      ),
      _model(
        'minutes',
        capabilities: const [ModelCapability.meetingSummarization],
      ),
    ];

    final visible = resolver.visibleProfiles(catalog);
    expect(
      visible.map((profile) => profile.id),
      contains(AiProfileId.meetingAssistant),
    );

    final overview = resolver.overviewProfiles(catalog);
    expect(
      overview.map((profile) => profile.id),
      contains(AiProfileId.meetingAssistant),
    );
    expect(
      overview.map((profile) => profile.id),
      isNot(contains(AiProfileId.voiceTranscription)),
    );
  });

  test('usedBy lists profiles whose automatic pick is this model', () {
    final chat = _model('chat', downloaded: true);
    final other = OfflineModelInfo(
      id: 'other-chat',
      name: 'other-chat',
      family: ModelFamily.other,
      fileSizeBytes: 4_000_000_000,
      filePath: '/tmp/other-chat',
      downloadUrl: 'https://example.test/model',
      capabilities: const [ModelCapability.chat],
      modalities: const [ModelModality.text],
    );

    final used = resolver.usedBy(chat, [other, chat]);
    expect(used, contains('Chat'));
  });
}
