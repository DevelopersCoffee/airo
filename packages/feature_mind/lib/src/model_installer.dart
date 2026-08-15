import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;

import 'models/model_descriptor_adapter.dart' as descriptors;
import 'models/model_provider.dart';

/// Puts the bundled models on disk. `ADR-0018 §2`, the **Bundled** strategy.
///
/// One [ModelProvider] implementation among several, and no longer the only
/// path: the standalone Airo Mind shell composes `DownloadModelProvider`
/// instead (`app/lib/core/mind/mind_model_sources.dart`), so it ships no model
/// weights in the APK. This stays for a build that intentionally bundles, for
/// tests that need no network, and as `MindService`'s own default — a service
/// constructed without a provider still copies from assets, which is the
/// behaviour it always had.
///
/// # This replaced the development fallback
///
/// Before this existed, `MindService` reached into the checkout's
/// `rust/.../models/` directory when nothing was installed. That made a
/// developer machine work and a device fail, which is the worst arrangement:
/// the failure only appears where it cannot be debugged.
class ModelInstaller with PinnedModelFiles implements ModelProvider {
  const ModelInstaller();

  /// Assets are addressed through the package, so the app that hosts Airo Mind
  /// does not have to re-declare them.
  static const String assetPrefix = 'packages/feature_mind/assets/models/';

  @override
  Future<List<RequiredModel>> requiredModels() =>
      descriptors.pinnedRequiredModels();

  /// The assets are already inside the app. Copying them costs no network, so
  /// `MindService` may run this acquisition without asking first.
  @override
  bool get acquiresWithoutNetwork => true;

  /// [ModelProvider.acquire]. Runs [install] and translates its
  /// copy-by-copy progress and its failed-file-name result into
  /// [ModelAcquisitionEvent]s — the copy logic itself is unchanged, only how
  /// its progress is reported.
  @override
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir) async* {
    final events = StreamController<ModelAcquisitionEvent>();
    final failedFuture = install(
      modelsDir,
      onProgress: (fileName, copied, total) {
        events.add(ModelAcquisitionProgress(fileName, copied, total));
      },
    );
    // The controller closes only after `install` has finished adding to it,
    // so nothing is dropped between the last progress event and the done
    // event that follows.
    unawaited(
      failedFuture.then((failed) {
        events.add(ModelAcquisitionDone(failed));
        events.close();
      }),
    );
    yield* events.stream;
  }

  /// Copies any missing model out of the asset bundle.
  ///
  /// [onProgress] reports `(fileName, copiedBytes, totalBytes)`. Half a
  /// gigabyte takes long enough that a silent first launch reads as a hang.
  ///
  /// Returns the names of models that could not be installed — an app built
  /// without the assets is a real state, and one the UI must be able to
  /// explain rather than crash on.
  Future<List<String>> install(
    Directory modelsDir, {
    void Function(String fileName, int copied, int total)? onProgress,
  }) async {
    final failed = <String>[];

    for (final required in await descriptors.pinnedRequiredModels()) {
      final target = File(p.join(modelsDir.path, required.fileName));
      final expected = required.sizeBytes;
      if (target.existsSync() && target.lengthSync() == expected) continue;

      // Wrong-sized residue is corrupt — clear before atomic reinstall so
      // a half-written file cannot pass the size check on a later launch.
      if (target.existsSync()) {
        try {
          target.deleteSync();
        } on Object {
          failed.add(required.fileName);
          continue;
        }
      }
      final leftoverPartial = File('${target.path}.partial');
      if (leftoverPartial.existsSync()) {
        try {
          leftoverPartial.deleteSync();
        } on Object {
          // Best-effort; the write path below recreates the partial.
        }
      }

      try {
        // Desktop bundles keep assets as real files. Copying file-to-file
        // streams; `rootBundle.load` would pull a 469 MB model entirely into
        // memory to write it straight back out.
        final onDisk = _assetFileOnDisk(required.fileName);
        if (onDisk != null) {
          final partial = File('${target.path}.partial');
          await onDisk.copy(partial.path);
          onProgress?.call(required.fileName, expected, expected);
          partial.renameSync(target.path);
          continue;
        }

        // Android and iOS keep assets inside the package, so there is no file
        // to copy and the whole model passes through memory once. Acceptable
        // for the speech model and heavy for the generation model; streaming
        // extraction needs a platform channel and is follow-up work, recorded
        // here rather than discovered on a low-memory device.
        final data = await rootBundle.load('$assetPrefix${required.fileName}');
        // Written to a temporary name and renamed, so an interrupted install
        // cannot leave a half-copied file that passes the size check on the
        // next launch.
        final partial = File('${target.path}.partial');
        final sink = partial.openSync(mode: FileMode.write);
        try {
          const chunk = 4 << 20;
          var offset = 0;
          while (offset < data.lengthInBytes) {
            final end = (offset + chunk).clamp(0, data.lengthInBytes);
            sink.writeFromSync(
              data.buffer.asUint8List(
                data.offsetInBytes + offset,
                end - offset,
              ),
            );
            offset = end;
            onProgress?.call(required.fileName, offset, data.lengthInBytes);
          }
        } finally {
          sink.closeSync();
        }
        partial.renameSync(target.path);
      } on Object {
        failed.add(required.fileName);
      }
    }
    return failed;
  }

  /// Locates an asset as a real file, where the platform keeps one.
  ///
  /// Returns null on Android and iOS, and on any desktop layout this has not
  /// seen — the caller falls back to `rootBundle` rather than failing.
  File? _assetFileOnDisk(String fileName) {
    if (Platform.isAndroid || Platform.isIOS) return null;

    final exeDir = File(Platform.resolvedExecutable).parent.path;
    for (final root in [
      // macOS
      p.join(
        exeDir,
        '..',
        'Frameworks',
        'App.framework',
        'Resources',
        'flutter_assets',
      ),
      // Linux and Windows
      p.join(exeDir, 'data', 'flutter_assets'),
    ]) {
      final candidate = File(p.normalize(p.join(root, assetPrefix, fileName)));
      if (candidate.existsSync()) return candidate;
    }
    return null;
  }

  /// Hashes every installed model against the digest pinned in Rust source.
  ///
  /// Off the launch path deliberately — see `models::resolve`, which documents
  /// the trade.
  @override
  Future<List<InstalledModel>> verify(Directory modelsDir) =>
      descriptors.verifyInstalledModels(modelsDir: modelsDir.path);
}
