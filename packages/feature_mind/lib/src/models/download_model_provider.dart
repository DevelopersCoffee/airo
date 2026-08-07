import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart' as core_ai;
import 'package:path/path.dart' as p;

import 'model_provider.dart';

/// [ModelProvider] backed by `core_ai`'s existing download pipeline — the same
/// `ModelDownloadService`/`ModelStorageManager` Airo already uses for its own
/// model catalog.
///
/// # Why the required-models lookup and the URL are both injected
///
/// `airo_mind_core::models` is the one pinned registry (file name, size,
/// sha256) and this provider must read it, not restate it — but that registry
/// crosses the bridge as `whisper.api.setup.requiredModels()`, and this class
/// must not import the generated bridge module directly. A provider that knows
/// the bridge exists is exactly the coupling the abstraction removes. The
/// caller (`MindService`, or a shell's composition root) supplies the lookup.
///
/// Similarly, `airo_mind_core::models` pins no download URL — the registry
/// only proves which bytes are correct, not where to find them, so hosting is
/// a Dart-side decision by design (`ADR-0018 §1`: the runtime never acquires
/// models). `downloadUrlFor` is where that decision is made, and it is a
/// constructor parameter rather than a hardcoded host so it can change without
/// touching this class.
class DownloadModelProvider implements ModelProvider {
  DownloadModelProvider({
    required this._downloadService,
    required this._requiredModelsLookup,
    required this._downloadUrlFor,
  });

  final core_ai.ModelDownloadService _downloadService;
  final Future<List<RequiredModel>> Function() _requiredModelsLookup;
  final String? Function(RequiredModel) _downloadUrlFor;

  @override
  Future<List<RequiredModel>> requiredModels() => _requiredModelsLookup();

  @override
  Future<bool> isInstalled(Directory modelsDir) async {
    for (final required in await requiredModels()) {
      final file = File(p.join(modelsDir.path, required.fileName));
      if (!file.existsSync()) return false;
      if (file.lengthSync() != required.sizeBytes) return false;
    }
    return true;
  }

  /// `core_ai.OfflineModelInfo.id` is the download service's identity for a
  /// model, and it must be the file name **without its extension**.
  ///
  /// `ModelStorageManager.getModelPath` -- which is what actually decides
  /// where the download is written, independently of [OfflineModelInfo.filePath]
  /// below -- builds the destination as `$id$extension`
  /// (`_artifactExtensionFor` infers the extension from `filePath`). Passing
  /// the full file name as `id` doubles the extension
  /// (`qwen….gguf` → `qwen….gguf.gguf`), so the download lands somewhere
  /// [ModelStorageManager.verifyModelIntegrity] never looks and the Rust
  /// bridge never reads. Verified end to end on device: 491 MB of qwen
  /// downloaded correctly, `verifyModelIntegrity` returned false instantly
  /// because it was hashing a file that was never written.
  core_ai.OfflineModelInfo _asOfflineModelInfo(
    RequiredModel required,
    Directory modelsDir,
  ) {
    final id = p.basenameWithoutExtension(required.fileName);
    return core_ai.OfflineModelInfo(
      id: id,
      name: required.fileName,
      // `family` is a catalog concern the download service does not act on
      // for a direct-URL fetch; `other` says so rather than guessing one.
      family: core_ai.ModelFamily.other,
      fileSizeBytes: required.sizeBytes,
      filePath: p.join(modelsDir.path, required.fileName),
      downloadUrl: _downloadUrlFor(required),
      sha256: required.sha256,
    );
  }

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {
    final required = await requiredModels();
    final failed = <String>[];

    // Sequential, not concurrent: the two Mind models together are ~570 MB,
    // and running both downloads at once on a constrained connection is a
    // worse experience than a predictable queue, not a faster one.
    for (final model in required) {
      final info = _asOfflineModelInfo(model, modelsDir);

      if (info.downloadUrl == null) {
        failed.add(model.fileName);
        continue;
      }

      var succeeded = false;
      var settled = false;
      // The service's progress stream is a persistent broadcast stream keyed
      // on model id -- it never closes on its own, so this loop breaks itself
      // on the first terminal status rather than waiting on stream closure.
      // `await for`'s implicit subscription is cancelled by `break`.
      await for (final progress in _downloadService.downloadModel(info)) {
        yield ModelAcquisitionProgress(
          model.fileName,
          progress.downloadedBytes,
          progress.totalBytes,
        );
        switch (progress.status) {
          case core_ai.ModelDownloadStatus.completed:
            succeeded = true;
            settled = true;
          case core_ai.ModelDownloadStatus.failed:
          case core_ai.ModelDownloadStatus.cancelled:
            succeeded = false;
            settled = true;
          case core_ai.ModelDownloadStatus.pending:
          case core_ai.ModelDownloadStatus.downloading:
          case core_ai.ModelDownloadStatus.paused:
          case core_ai.ModelDownloadStatus.verifying:
            break;
        }
        if (settled) break;
      }

      if (!succeeded) failed.add(model.fileName);
    }

    yield ModelAcquisitionDone(failed);
  }

  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) async {
    final required = await requiredModels();
    final results = <InstalledModel>[];
    for (final model in required) {
      final file = File(p.join(modelsDir.path, model.fileName));
      if (!file.existsSync()) {
        results.add(
          InstalledModel(
            fileName: model.fileName,
            present: false,
            verified: false,
            detail: 'not installed',
          ),
        );
        continue;
      }
      final info = _asOfflineModelInfo(model, modelsDir);
      final ok = await core_ai.ModelStorageManager().verifyModelIntegrity(info);
      results.add(
        InstalledModel(
          fileName: model.fileName,
          present: true,
          verified: ok,
          detail: ok ? 'verified' : 'digest mismatch',
        ),
      );
    }
    return results;
  }
}
