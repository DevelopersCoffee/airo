import 'dart:async';
import 'dart:io';

import 'package:core_ai/core_ai.dart' as core_ai;
import 'package:path/path.dart' as p;

import 'model_descriptor_adapter.dart' as descriptors;
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
    Duration stallThreshold = const Duration(seconds: 90),
    Duration stallPollInterval = const Duration(seconds: 2),
  }) : _stallThreshold = stallThreshold,
       _stallPollInterval = stallPollInterval;

  final core_ai.ModelDownloadService _downloadService;

  /// How long a transfer may report downloading with no byte movement before
  /// acquisition treats it as stalled. Matches `ModelDownloadProgress`'s
  /// default stall window so Mind first-run and the shared model explorer
  /// agree on when to offer recovery.
  final Duration _stallThreshold;

  /// How often the stall watchdog re-checks [ModelDownloadProgress.isStalledAt]
  /// even when the platform stops emitting progress (WorkManager FGS timeout).
  final Duration _stallPollInterval;

  /// Closes the download pipeline this provider was composed over: it holds a
  /// subscription to the platform download stream and a progress controller
  /// per model, neither of which the shell can reach once the provider is
  /// inside `MindService`.
  @override
  Future<void> dispose() => _downloadService.dispose();
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
    // Identity (file size, digest) is translated by the model-descriptor
    // adapter (#1673); `family: other` says the download service does not
    // act on it for a direct-URL fetch, rather than guessing one.
    return descriptors.offlineModelInfoFromRequiredModel(
      required,
      id: _stagedId(required),
      name: required.fileName,
      family: core_ai.ModelFamily.other,
      downloadUrl: _downloadUrlFor(required),
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
  /// Staging lands at `$target.partial` first, then is renamed into place —
  /// the same atomic pattern as [ModelInstaller] — so a kill mid-install
  /// cannot leave a wrong-sized file that [PinnedModelFiles.isPresent] would
  /// treat as installed on the next launch. Wrong-sized leftovers (partial
  /// or final) are deleted before promotion; corrupt never becomes loadable.
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
    final partial = File('${target.path}.partial');

    try {
      if (PinnedModelFiles.isPresent(modelsDir, required)) return true;

      // Wrong-sized final or leftover partial is corrupt residue — never
      // treat it as installed, and clear it before promoting a fresh artifact.
      if (target.existsSync()) {
        target.deleteSync();
      }
      if (partial.existsSync()) {
        partial.deleteSync();
      }

      // The same id the download was enqueued under — anything else asks the
      // storage manager about a model it never wrote.
      final stagedPath = await _downloadService.resolveExistingModelPath(
        _stagedId(required),
        model: _stagedInfo(required),
      );
      if (stagedPath == null) return false;

      final staged = File(stagedPath);
      try {
        staged.renameSync(partial.path);
      } on FileSystemException {
        staged.copySync(partial.path);
        staged.deleteSync();
      }

      if (!partial.existsSync() || partial.lengthSync() != required.sizeBytes) {
        if (partial.existsSync()) partial.deleteSync();
        return false;
      }

      partial.renameSync(target.path);
      return PinnedModelFiles.isPresent(modelsDir, required);
    } on Object {
      if (partial.existsSync()) {
        try {
          partial.deleteSync();
        } on Object {
          // Best-effort cleanup; the next acquire clears leftovers above.
        }
      }
      return false;
    }
  }

  /// Re-attaches to WorkManager / URLSession state left from a previous
  /// process, and kicks resume/retry when the platform retained a partial.
  Future<Map<String, core_ai.ModelDownloadProgress>> _restorePersisted({
    required List<RequiredModel> required,
  }) async {
    final catalog = [for (final model in required) _stagedInfo(model)];
    final restored = await _downloadService.restoreQueue(
      catalogModels: catalog,
    );
    return {for (final progress in restored) progress.modelId: progress};
  }

  Future<void> _resumeOrRetryIfNeeded(
    RequiredModel model,
    core_ai.OfflineModelInfo info,
    core_ai.ModelDownloadProgress? prior,
  ) async {
    if (prior == null) return;
    // An in-flight restored transfer needs no kick — only paused / failed /
    // stalled entries are recovered so we do not cancel live WorkManager work.
    final needsRecovery =
        prior.status == core_ai.ModelDownloadStatus.paused ||
        prior.status == core_ai.ModelDownloadStatus.failed ||
        prior.isStalled;
    if (!needsRecovery) return;

    await _downloadService.recoverDownload(
      info.id,
      model: info,
      resumeSupported:
          prior.resumeSupported ||
          prior.status == core_ai.ModelDownloadStatus.paused ||
          prior.downloadedBytes > 0,
    );
  }

  /// Listens to [ModelDownloadService.downloadModel] until a terminal status,
  /// synthesizing failure when bytes stop moving — including when the
  /// platform stops emitting events after an FGS / WorkManager timeout.
  Stream<core_ai.ModelDownloadProgress> _watchDownload(
    core_ai.OfflineModelInfo info,
  ) {
    late final StreamController<core_ai.ModelDownloadProgress> controller;
    StreamSubscription<core_ai.ModelDownloadProgress>? subscription;
    Timer? watchdog;
    core_ai.ModelDownloadProgress? latest;
    final watchStartedAt = DateTime.now();
    var closed = false;

    Future<void> close() async {
      if (closed) return;
      closed = true;
      watchdog?.cancel();
      await subscription?.cancel();
      await controller.close();
    }

    void emitStallFailure(core_ai.ModelDownloadProgress? progress) {
      if (closed || controller.isClosed) return;
      final bytes = progress?.downloadedBytes ?? 0;
      final total = progress?.totalBytes ?? info.fileSizeBytes;
      controller.add(
        core_ai.ModelDownloadProgress(
          modelId: info.id,
          totalBytes: total,
          downloadedBytes: bytes,
          status: core_ai.ModelDownloadStatus.failed,
          startTime: progress?.startTime ?? watchStartedAt,
          lastProgressAt: progress?.lastProgressAt ?? watchStartedAt,
          error:
              'Download stalled — no progress for '
              '${_stallThreshold.inSeconds}s.',
          failureCode: 'stalled',
          retryCount: progress?.retryCount ?? 0,
          queuePosition: progress?.queuePosition,
          resumeSupported: progress?.resumeSupported == true || bytes > 0,
        ),
      );
      unawaited(close());
    }

    void armWatchdog() {
      watchdog?.cancel();
      watchdog = Timer.periodic(_stallPollInterval, (_) {
        if (closed) return;
        final now = DateTime.now();
        final progress = latest;
        if (progress != null) {
          if (progress.isStalledAt(now, threshold: _stallThreshold)) {
            emitStallFailure(progress);
          }
          return;
        }
        // Enqueued but silent — the platform never reported a first byte.
        if (now.difference(watchStartedAt) >= _stallThreshold) {
          emitStallFailure(null);
        }
      });
    }

    controller = StreamController<core_ai.ModelDownloadProgress>(
      onListen: () {
        armWatchdog();
        subscription = _downloadService
            .downloadModel(info)
            .listen(
              (progress) {
                latest = progress;
                if (closed || controller.isClosed) return;
                controller.add(progress);
                final terminal =
                    progress.status == core_ai.ModelDownloadStatus.completed ||
                    progress.status == core_ai.ModelDownloadStatus.failed ||
                    progress.status == core_ai.ModelDownloadStatus.cancelled;
                if (terminal) {
                  unawaited(close());
                  return;
                }
                if (progress.isStalled) {
                  emitStallFailure(progress);
                  return;
                }
                armWatchdog();
              },
              onError: (Object error, StackTrace stackTrace) {
                if (!closed && !controller.isClosed) {
                  controller.addError(error, stackTrace);
                }
                unawaited(close());
              },
              onDone: () => unawaited(close()),
            );
      },
      onCancel: close,
    );
    return controller.stream;
  }

  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {
    yield* acquireFiles(modelsDir, await requiredModels());
  }

  /// Downloads and installs an arbitrary pinned list — used for optional pro
  /// packs such as Sarvam-1 that are not part of [requiredModels].
  Stream<ModelAcquisitionEvent> acquireFiles(
    Directory modelsDir,
    List<RequiredModel> models,
  ) async* {
    final failed = <String>[];
    var resumeSupported = false;

    // Rehydrate WorkManager / URLSession queue so a cold start can continue
    // a ~570 MB scribe transfer instead of discarding the partial.
    final restored = await _restorePersisted(required: models);

    // Sequential, not concurrent: the two Mind models together are ~570 MB,
    // and running both downloads at once on a constrained connection is a
    // worse experience than a predictable queue, not a faster one.
    for (final model in models) {
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

      final prior = restored[info.id];
      if (prior != null && prior.downloadedBytes > 0) {
        resumeSupported = true;
        yield ModelAcquisitionProgress(
          model.fileName,
          prior.downloadedBytes,
          prior.totalBytes > 0 ? prior.totalBytes : model.sizeBytes,
        );
      }
      await _resumeOrRetryIfNeeded(model, info, prior);

      var succeeded = false;
      var settled = false;
      // The service's progress stream is a persistent broadcast stream keyed
      // on model id -- it never closes on its own, so this loop breaks itself
      // on the first terminal status rather than waiting on stream closure.
      // `await for`'s implicit subscription is cancelled by `break`.
      await for (final progress in _watchDownload(info)) {
        if (progress.downloadedBytes > 0 && progress.resumeSupported) {
          resumeSupported = true;
        }
        yield ModelAcquisitionProgress(
          model.fileName,
          progress.downloadedBytes,
          progress.totalBytes > 0 ? progress.totalBytes : model.sizeBytes,
        );
        switch (progress.status) {
          case core_ai.ModelDownloadStatus.completed:
            succeeded = true;
            settled = true;
          case core_ai.ModelDownloadStatus.failed:
          case core_ai.ModelDownloadStatus.cancelled:
            succeeded = false;
            settled = true;
            if (progress.resumeSupported || progress.downloadedBytes > 0) {
              resumeSupported = true;
            }
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

    yield ModelAcquisitionDone(failed, resumeSupported: resumeSupported);
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
