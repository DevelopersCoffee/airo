import 'package:flutter/foundation.dart';

import '../download/model_download_service.dart';
import '../models/offline_model_info.dart';
import '../registry/model_catalog.dart';
import 'embedding_client.dart';

/// What the caller wants embedded.
enum EmbeddingInputKind { text, image, audio }

/// Smallest installed embedding package whose modalities cover [kind].
///
/// Text stays on EmbeddingGemma 2 270M when it is installed. Image prefers
/// the 440M text-and-vision package over the 740M package. Audio needs the
/// 740M package.
OfflineModelInfo? selectEmbeddingModel(
  List<OfflineModelInfo> installed,
  EmbeddingInputKind kind,
) {
  final matches = installed.where((model) {
    if (!model.capabilities.contains(ModelCapability.embeddings)) {
      return false;
    }
    return switch (kind) {
      EmbeddingInputKind.text =>
        model.modalities.isEmpty ||
            model.modalities.contains(ModelModality.text),
      EmbeddingInputKind.image => model.modalities.contains(
        ModelModality.image,
      ),
      EmbeddingInputKind.audio => model.modalities.contains(
        ModelModality.audio,
      ),
    };
  }).toList();
  if (matches.isEmpty) return null;
  matches.sort((a, b) => a.fileSizeBytes.compareTo(b.fileSizeBytes));
  return matches.first;
}

/// Why [EmbeddingService.embed] cannot answer right now. Mirrors
/// `MindUnavailable`'s shape: each case is one the caller can act on.
enum EmbeddingUnavailable {
  /// No catalog model tagged [ModelCapability.embeddings] is downloaded yet.
  /// The ordinary first-run state — not an error.
  noModelInstalled,

  /// A model is installed, but loading or running it failed.
  modelFailed,
}

/// The result of [EmbeddingService.embed].
@immutable
class EmbeddingResult {
  const EmbeddingResult.ready(List<double> this.vector, String this.modelId)
    : unavailable = null,
      detail = '';

  const EmbeddingResult.unavailable(this.unavailable, this.detail)
    : vector = null,
      modelId = null;

  final List<double>? vector;

  /// Which catalog entry produced [vector] — null unless [isReady]. Callers
  /// that persist a vector (e.g. `MeetingEmbeddingStore`) need this to detect
  /// staleness later (`ADR-0018 §5`'s "record what produced this" pattern);
  /// `EmbeddingService` is the only thing that knows which model
  /// `TaskModelRouter` actually resolved for a given call.
  final String? modelId;
  final EmbeddingUnavailable? unavailable;
  final String detail;

  bool get isReady => vector != null;
}

/// Picks an installed embedding package and turns text, an image, or audio
/// into a vector, without ever acquiring a model itself.
///
/// [selectEmbeddingModel] picks the smallest installed package that can
/// represent the input. [EmbeddingClient] is the native call once that file,
/// and a tokenizer when the older TFLite model needs one, is on disk.
///
/// "Installed" is checked, never made true: this service calls
/// `ModelDownloadService.isModelDownloaded`, never `downloadModel`.
class EmbeddingService {
  EmbeddingService({
    EmbeddingClient? client,
    ModelDownloadService? downloadService,
    List<OfflineModelInfo>? catalog,
  }) : _client = client ?? MethodChannelEmbeddingClient(),
       _downloadService = downloadService ?? ModelDownloadService(),
       _catalog = catalog ?? ModelCatalog.bundledModels;

  final EmbeddingClient _client;
  final ModelDownloadService _downloadService;
  final List<OfflineModelInfo> _catalog;

  String? _initializedModelId;

  /// Turns [text] into its embedding vector.
  ///
  /// Never throws: an expected "nothing installed yet" state and an
  /// unexpected native failure are both a typed [EmbeddingResult], not an
  /// exception a caller must remember to catch.
  ///
  /// [taskType] selects query vs document encoding when the native plugin
  /// supports it — defaults to symmetric similarity for callers that do not
  /// care.
  Future<EmbeddingResult> embed(
    String text, {
    EmbeddingTaskType taskType = EmbeddingTaskType.semanticSimilarity,
  }) {
    return _run(
      EmbeddingInputKind.text,
      'No embedding model is installed yet.',
      (resolved) => _client.embed(text: text, taskType: taskType),
    );
  }

  /// Embeds a photo with the smallest installed vision embedding package.
  Future<EmbeddingResult> embedImage(String imagePath) {
    return _run(
      EmbeddingInputKind.image,
      'No image embedding model is installed yet.',
      (_) => _client.embedMedia(imagePath: imagePath),
    );
  }

  /// Embeds an audio file with the installed audio embedding package.
  Future<EmbeddingResult> embedAudio(String audioPath) {
    return _run(
      EmbeddingInputKind.audio,
      'No audio embedding model is installed yet.',
      (_) => _client.embedMedia(audioPath: audioPath),
    );
  }

  Future<EmbeddingResult> _run(
    EmbeddingInputKind kind,
    String missingMessage,
    Future<List<double>> Function(OfflineModelInfo resolved) embed,
  ) async {
    final installed = <OfflineModelInfo>[];
    for (final candidate in _catalog) {
      if (candidate.capabilities.isEmpty) continue;
      if (await _downloadService.isModelDownloaded(
        candidate.id,
        model: candidate,
      )) {
        installed.add(candidate);
      }
    }

    final resolved = selectEmbeddingModel(installed, kind);
    if (resolved == null) {
      return EmbeddingResult.unavailable(
        EmbeddingUnavailable.noModelInstalled,
        missingMessage,
      );
    }

    try {
      if (_initializedModelId != resolved.id) {
        final modelPath = await _downloadService.getModelPath(
          resolved.id,
          model: resolved,
        );
        if (isLiteRtEmbeddingPackage(resolved, modelPath: modelPath)) {
          await _client.initialize(modelPath: modelPath, tokenizerPath: '');
        } else {
          final tokenizer = _catalog.firstWhere(
            (candidate) =>
                candidate.tags.contains('tokenizer') &&
                candidate.tags.contains(resolved.id),
            orElse: () => throw StateError(
              'No tokenizer catalog entry tags itself for ${resolved.id}',
            ),
          );
          final tokenizerPath = await _downloadService.getModelPath(
            tokenizer.id,
            model: tokenizer,
          );
          await _client.initialize(
            modelPath: modelPath,
            tokenizerPath: tokenizerPath,
          );
        }
        _initializedModelId = resolved.id;
      }

      final vector = await embed(resolved);
      return EmbeddingResult.ready(vector, resolved.id);
    } on Object catch (e) {
      return EmbeddingResult.unavailable(
        EmbeddingUnavailable.modelFailed,
        '$e',
      );
    }
  }
}
