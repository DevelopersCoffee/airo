import 'package:flutter/foundation.dart';

import '../download/model_download_service.dart';
import '../models/offline_model_info.dart';
import '../registry/model_catalog.dart';
import '../router/ai_task.dart';
import '../router/task_model_router.dart';
import 'embedding_client.dart';

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

/// Resolves `AiTask.embeddings` to an installed model and turns text into a
/// vector, without ever acquiring a model itself.
///
/// Two collaborators do the actual work: [TaskModelRouter] picks *which*
/// catalog entry answers `AiTask.embeddings` (PR #1564's contract, unchanged
/// here), and [EmbeddingClient] is the native call once a model and its
/// paired tokenizer are known to be on disk
/// (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`).
///
/// "Installed" is checked, never made true: this service calls
/// `ModelDownloadService.isModelDownloaded`, never `downloadModel` — the same
/// boundary `ModelProvider` draws elsewhere in this app. A caller that wants
/// the model downloaded goes through the model-library UI, the same as every
/// other catalog entry.
class EmbeddingService {
  EmbeddingService({
    EmbeddingClient? client,
    ModelDownloadService? downloadService,
    TaskModelRouter? router,
    List<OfflineModelInfo>? catalog,
  }) : _client = client ?? MethodChannelEmbeddingClient(),
       _downloadService = downloadService ?? ModelDownloadService(),
       _router = router ?? const TaskModelRouter(),
       _catalog = catalog ?? ModelCatalog.bundledModels;

  final EmbeddingClient _client;
  final ModelDownloadService _downloadService;
  final TaskModelRouter _router;
  final List<OfflineModelInfo> _catalog;

  bool _initialized = false;

  /// Turns [text] into its embedding vector.
  ///
  /// Never throws: an expected "nothing installed yet" state and an
  /// unexpected native failure are both a typed [EmbeddingResult], not an
  /// exception a caller must remember to catch.
  Future<EmbeddingResult> embed(String text) async {
    final installed = <OfflineModelInfo>[];
    for (final candidate in _catalog) {
      // Skip capability-less entries (the tokenizer) before ever asking the
      // download service about them -- they can never resolve a task, so
      // checking their download state would be work with no possible answer.
      if (candidate.capabilities.isEmpty) continue;
      if (await _downloadService.isModelDownloaded(
        candidate.id,
        model: candidate,
      )) {
        installed.add(candidate);
      }
    }

    final resolved = _router.resolve(AiTask.embeddings, installed);
    if (resolved == null) {
      return const EmbeddingResult.unavailable(
        EmbeddingUnavailable.noModelInstalled,
        'No embedding model is installed yet.',
      );
    }

    try {
      if (!_initialized) {
        final tokenizer = _catalog.firstWhere(
          (candidate) =>
              candidate.tags.contains('tokenizer') &&
              candidate.tags.contains(resolved.id),
          orElse: () => throw StateError(
            'No tokenizer catalog entry tags itself for ${resolved.id}',
          ),
        );
        final modelPath = await _downloadService.getModelPath(
          resolved.id,
          model: resolved,
        );
        final tokenizerPath = await _downloadService.getModelPath(
          tokenizer.id,
          model: tokenizer,
        );
        await _client.initialize(
          modelPath: modelPath,
          tokenizerPath: tokenizerPath,
        );
        _initialized = true;
      }

      final vector = await _client.embed(text: text);
      return EmbeddingResult.ready(vector, resolved.id);
    } on Object catch (e) {
      return EmbeddingResult.unavailable(
        EmbeddingUnavailable.modelFailed,
        '$e',
      );
    }
  }
}
