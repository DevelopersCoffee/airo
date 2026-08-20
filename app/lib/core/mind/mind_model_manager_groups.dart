import 'package:core_ai/core_ai.dart';

/// Visible sections in the Mind Intelligent Model Manager.
///
/// Image generation, TTS, ONNX speaker embeddings, and Android-only LiteRT
/// rows stay hidden until a runtime exists for this host.
enum MindModelManagerGroup { textChat, transcription }

/// Catalog rows split for the Mind manager list.
class MindModelManagerPartition {
  const MindModelManagerPartition({
    required this.textChat,
    required this.transcription,
  });

  final List<ModelEntry> textChat;
  final List<ModelEntry> transcription;

  bool get isEmpty => textChat.isEmpty && transcription.isEmpty;
}

/// Groups [OfflineModelInfo] for the Mind manager without a new metadata type.
class MindModelManagerGroups {
  const MindModelManagerGroups._();

  static MindModelManagerGroup? groupFor(
    OfflineModelInfo model, {
    required ModelRuntimeProfile profile,
  }) {
    if (!profile.offersPackage(model)) return null;
    if (_isTranscription(model)) return MindModelManagerGroup.transcription;
    if (_isTextChatGguf(model)) return MindModelManagerGroup.textChat;
    return null;
  }

  static MindModelManagerPartition partition({
    required List<ModelEntry> entries,
    required OfflineModelInfo? Function(String id) lookup,
    required ModelRuntimeProfile profile,
  }) {
    final textChat = <ModelEntry>[];
    final transcription = <ModelEntry>[];
    for (final entry in entries) {
      final info = lookup(entry.id);
      if (info == null) continue;
      switch (groupFor(info, profile: profile)) {
        case MindModelManagerGroup.textChat:
          textChat.add(entry);
        case MindModelManagerGroup.transcription:
          transcription.add(entry);
        case null:
          break;
      }
    }
    return MindModelManagerPartition(
      textChat: textChat,
      transcription: transcription,
    );
  }

  static bool _isTranscription(OfflineModelInfo model) {
    if (model.effectiveRuntime == InferenceRuntime.onnx) return false;
    if (model.effectiveRuntime == InferenceRuntime.whisper) return true;
    if (model.effectiveTask == ModelTask.speechToText) return true;
    final blob = _searchBlob(model);
    return blob.contains('whisper') ||
        blob.contains('ggml-tiny') ||
        blob.contains('ggml-small');
  }

  static bool _isTextChatGguf(OfflineModelInfo model) {
    if (model.effectiveRuntime != InferenceRuntime.llamaCpp) return false;
    if (model.effectiveTask == ModelTask.vision ||
        model.effectiveTask == ModelTask.embedding ||
        model.effectiveTask == ModelTask.classification) {
      return false;
    }
    return _looksLikeGguf(model);
  }

  static bool _looksLikeGguf(OfflineModelInfo model) {
    if (model.provider == AIProvider.gguf) return true;
    if (model.tags.any((tag) => tag.toLowerCase() == 'gguf')) return true;
    return ModelContractInference.artifactKey(model).contains('.gguf');
  }

  static String _searchBlob(OfflineModelInfo model) {
    return '${model.id} ${model.name} ${model.huggingFaceId ?? ''} '
            '${ModelContractInference.artifactKey(model)}'
        .toLowerCase();
  }
}
