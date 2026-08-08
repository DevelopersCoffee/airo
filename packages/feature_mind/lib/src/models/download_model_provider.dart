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
class DownloadModelProvider with PinnedModelFiles implements ModelProvider {
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

  /// Roughly 570 MB over the network. `MindService` must offer this rather
  /// than start it.
  @override
  bool get acquiresWithoutNetwork => false;

  /// `core_ai.OfflineModelInfo.id` is the download service's identity for a
  /// model, and it must be the pinned file name **without its extension**.
  ///
  /// `ModelStorageManager.getModelPath` composes the staging destination as
  /// `$id$extension`, inferring the extension from `filePath` or, failing
  /// that, from the download URL. Handing it the whole file name therefore
  /// doubles the extension (`qwen….gguf` → `qwen….gguf.gguf`). Nothing
  /// downstream broke — [_install] resolves the staged artifact through the
  /// same manager, which tries every supported extension — but the doubled
  /// name is a trap for anything that looks at the staging directory directly
  /// (`verifyModelIntegrity` on a bare id, an `adb ls`, a human), so the id is
  /// stripped here (#1553).
  ///
  /// [filePath] is deliberately left null for the **download**: the download
  /// service resolves its own destination from `ModelStorageManager` and
  /// re-verifies the artifact there when the transport completes. Handing it a
  /// path in Mind's directory does not move the download — `getModelPath`
  /// ignores everything but the extension — it only makes that post-download
  /// verification look at a file the transport never wrote, so every download
  /// would report `integrity_mismatch`. The bytes are therefore staged by
  /// `core_ai` and moved into [modelsDir] by [_install] once they are
  /// verified.
  static String _stagedId(RequiredModel required) =>
      p.basenameWithoutExtension(required.fileName);

  core_ai.OfflineModelInfo _stagedInfo(RequiredModel required) {
    return core_ai.OfflineModelInfo(
      id: _stagedId(required),
      name: required.fileName,
      // `family` is a catalog concern the download service does not act on
      // for a direct-URL fetch; `other` says so rather than guessing one.
      family: core_ai.ModelFamily.other,
      fileSizeBytes: required.sizeBytes,
      downloadUrl: _downloadUrlFor(required),
      sha256: required.sha256,
    );
  }

  /// The same model, addressed where Airo Mind keeps it: the Rust engines are
  /// handed one directory (`ADR-0018 §1`) and read the pinned file names out
  /// of it, so this is the only location that counts as installed.
  core_ai.OfflineModelInfo _installedInfo(
    RequiredModel required,
    Directory modelsDir,
  ) => _stagedInfo(
    required,
  ).copyWith(filePath: p.join(modelsDir.path, required.fileName));

  /// Moves a verified artifact out of `core_ai`'s staging directory and into
  /// Mind's models directory, under its pinned file name.
  ///
  /// A rename, not a copy: both directories live under the same app container
  /// on every platform Mind ships to, so this is a metadata operation rather
  /// than half a gigabyte read and written again. The copy path is the honest
  /// fallback for a layout where they are not.
  ///
  /// Every failure is one file's failure, reported by name. Letting one throw
  /// would abort the `async*` stream mid-acquisition: no
  /// [ModelAcquisitionDone], the second model never attempted, and a raw
  /// exception on screen instead of a retry.
  Future<bool> _install(RequiredModel required, Directory modelsDir) async {
    final target = File(p.join(modelsDir.path, required.fileName));

    try {
      if (PinnedModelFiles.isPresent(modelsDir, required)) return true;

      // The same id the download was enqueued under — anything else asks the
      // storage manager about a model it never wrote.
      final stagedPath = await _downloadService.resolveExistingModelPath(
        _stagedId(required),
        model: _stagedInfo(required),
      );
      if (stagedPath == null) return false;

      final staged = File(stagedPath);
      try {
        staged.renameSync(target.path);
      } on FileSystemException {
        staged.copySync(target.path);
        staged.deleteSync();
      }
      return PinnedModelFiles.isPresent(modelsDir, required);
    } on Object {
      return false;
    }
  }

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {
    final required = await requiredModels();
    final failed = <String>[];

    // Sequential, not concurrent: the two Mind models together are ~570 MB,
    // and running both downloads at once on a constrained connection is a
    // worse experience than a predictable queue, not a faster one.
    for (final model in required) {
      if (PinnedModelFiles.isPresent(modelsDir, model)) {
        // Already installed. Only some of the set is usually missing, and
        // re-fetching 469 MB because 77 MB is absent is not a retry anyone
        // asked for.
        yield ModelAcquisitionProgress(
          model.fileName,
          model.sizeBytes,
          model.sizeBytes,
        );
        continue;
      }

      final info = _stagedInfo(model);

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

      // Verified bytes in the staging directory are not yet an installed
      // model: the engines only read [modelsDir].
      if (succeeded) succeeded = await _install(model, modelsDir);

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
      final info = _installedInfo(model, modelsDir);
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
