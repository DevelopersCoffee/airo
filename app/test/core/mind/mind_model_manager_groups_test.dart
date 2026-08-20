import 'package:airo_app/core/mind/mind_model_manager_groups.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const profile = ModelRuntimeProfile.desktopGguf;

  OfflineModelInfo qwen() => const OfflineModelInfo(
    id: 'mind-scribe-qwen2.5-0.5b-instruct',
    name: 'Qwen2.5 0.5B Instruct',
    family: ModelFamily.qwen,
    fileSizeBytes: 400000000,
    filePath: '/models/qwen2.5-0.5b-instruct-q4_k_m.gguf',
    provider: AIProvider.gguf,
  );

  OfflineModelInfo whisper() => const OfflineModelInfo(
    id: 'mind-scribe-whisper-tiny-en',
    name: 'Whisper Tiny (English)',
    family: ModelFamily.other,
    fileSizeBytes: 77691713,
    filePath: '/models/ggml-tiny.en.bin',
    huggingFaceId: 'ggerganov/whisper.cpp',
    modalities: [ModelModality.audio, ModelModality.text],
    capabilities: [ModelCapability.audioUnderstanding],
  );

  OfflineModelInfo ecapa() => const OfflineModelInfo(
    id: 'mind-scribe-ecapa-diarize',
    name: 'ECAPA speaker embeddings',
    family: ModelFamily.other,
    fileSizeBytes: 83000000,
    filePath: '/models/ecapa_tdnn_tiny_int8.onnx',
    modalities: [ModelModality.audio],
    capabilities: [ModelCapability.audioUnderstanding],
  );

  OfflineModelInfo liteRt() => const OfflineModelInfo(
    id: 'gemma-4-e2b-it-litertlm',
    name: 'Gemma-4-E2B-it',
    family: ModelFamily.gemma,
    fileSizeBytes: 2588147712,
    filePath: '/models/gemma-4-e2b-it.litertlm',
    runtime: InferenceRuntime.litertLm,
    platformSupport: PlatformSupport.androidOnly(),
  );

  OfflineModelInfo hfGguf() => const OfflineModelInfo(
    id: 'hf-phi-3-mini',
    name: 'Phi-3 Mini',
    family: ModelFamily.phi,
    fileSizeBytes: 2000000000,
    downloadUrl:
        'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf',
    provider: AIProvider.gguf,
    tags: ['huggingface', 'gguf'],
  );

  test('desktop Mind keeps llama.cpp GGUF under Text & Chat', () {
    expect(
      MindModelManagerGroups.groupFor(qwen(), profile: profile),
      MindModelManagerGroup.textChat,
    );
    expect(
      MindModelManagerGroups.groupFor(hfGguf(), profile: profile),
      MindModelManagerGroup.textChat,
    );
  });

  test('desktop Mind keeps Whisper under Audio transcription', () {
    expect(
      MindModelManagerGroups.groupFor(whisper(), profile: profile),
      MindModelManagerGroup.transcription,
    );
  });

  test('desktop Mind hides ONNX, LiteRT, and vision packages', () {
    expect(MindModelManagerGroups.groupFor(ecapa(), profile: profile), isNull);
    expect(MindModelManagerGroups.groupFor(liteRt(), profile: profile), isNull);
    expect(
      MindModelManagerGroups.groupFor(
        const OfflineModelInfo(
          id: 'sd-gguf',
          name: 'Fake image GGUF',
          family: ModelFamily.other,
          fileSizeBytes: 1,
          filePath: '/models/sd.gguf',
          provider: AIProvider.gguf,
          task: ModelTask.vision,
        ),
        profile: profile,
      ),
      isNull,
    );
  });

  test('partition preserves catalog order inside each group', () {
    const entries = [
      ModelEntry(
        id: 'mind-scribe-whisper-tiny-en',
        name: 'Whisper Tiny (English)',
        version: 'Unversioned',
        description: 'asr',
        sizeBytes: 1,
        updateState: ModelUpdateState.unknown,
      ),
      ModelEntry(
        id: 'mind-scribe-qwen2.5-0.5b-instruct',
        name: 'Qwen2.5 0.5B Instruct',
        version: 'Unversioned',
        description: 'chat',
        sizeBytes: 1,
        updateState: ModelUpdateState.unknown,
      ),
      ModelEntry(
        id: 'mind-scribe-ecapa-diarize',
        name: 'ECAPA speaker embeddings',
        version: 'Unversioned',
        description: 'onnx',
        sizeBytes: 1,
        updateState: ModelUpdateState.unknown,
      ),
    ];
    final lookup = {
      'mind-scribe-whisper-tiny-en': whisper(),
      'mind-scribe-qwen2.5-0.5b-instruct': qwen(),
      'mind-scribe-ecapa-diarize': ecapa(),
    };

    final partition = MindModelManagerGroups.partition(
      entries: entries,
      lookup: (id) => lookup[id],
      profile: profile,
    );

    expect(partition.textChat.single.id, 'mind-scribe-qwen2.5-0.5b-instruct');
    expect(partition.transcription.single.id, 'mind-scribe-whisper-tiny-en');
    expect(partition.isEmpty, isFalse);
  });
}
