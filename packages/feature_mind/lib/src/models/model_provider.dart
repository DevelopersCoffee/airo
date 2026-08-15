import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A model that must be on disk, and what proves it is the right one.
///
/// Deliberately not the generated `whisper.api.setup.RequiredModel` (a
/// `BigInt` wire type from the bridge): a `ModelProvider` must not know the
/// bridge exists. `ModelInstaller` and `DownloadModelProvider` both translate
/// the pinned Rust registry into this shape.
@immutable
class RequiredModel {
  const RequiredModel({
    required this.fileName,
    required this.sizeBytes,
    required this.sha256,
  });

  final String fileName;
  final int sizeBytes;

  /// Pinned in `airo_mind_core::models` (`ADR-0018 §2`). Every provider
  /// verifies against this same value; none of them invent their own.
  final String sha256;
}

/// What a model looks like right now, after [ModelProvider.verify].
@immutable
class InstalledModel {
  const InstalledModel({
    required this.fileName,
    required this.present,
    required this.verified,
    required this.detail,
  });

  final String fileName;
  final bool present;

  /// Only meaningful when [present]. False means the bytes on disk are not
  /// the bytes that were pinned.
  final bool verified;
  final String detail;
}

/// Progress through [ModelProvider.acquire], file by file.
sealed class ModelAcquisitionEvent {
  const ModelAcquisitionEvent();
}

/// One file, some fraction of its bytes obtained.
final class ModelAcquisitionProgress extends ModelAcquisitionEvent {
  const ModelAcquisitionProgress(this.fileName, this.fetched, this.total);

  final String fileName;
  final int fetched;
  final int total;
}

/// Acquisition finished. [failedFileNames] is empty on full success — a real
/// state (no network, no bundled asset, a corrupt file, a stalled transfer)
/// that the UI must be able to explain rather than crash on.
///
/// [resumeSupported] is true when the platform retained partial bytes for at
/// least one failure, so the shell can offer "Resume download" instead of a
/// cold "Try again".
final class ModelAcquisitionDone extends ModelAcquisitionEvent {
  const ModelAcquisitionDone(
    this.failedFileNames, {
    this.resumeSupported = false,
  });

  final List<String> failedFileNames;

  /// Whether a later acquire can continue from retained partial files.
  final bool resumeSupported;
}

/// Where model bytes come from. `MindService` and the UI depend on this,
/// never on a concrete source — `ModelInstaller` (bundled asset) and
/// `DownloadModelProvider` (Airo's existing download pipeline, `core_ai`) are
/// two implementations, not two special cases the caller has to know about.
///
/// Neither implementation may reach into `airo_mind_core`'s Rust registry
/// directly from this abstraction: the pinned digest crosses the bridge once,
/// through the bridge's own `required_files`/`requiredModels`, and every
/// provider verifies against that same value. See
/// `docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`.
abstract interface class ModelProvider {
  Future<List<RequiredModel>> requiredModels();

  /// True when [acquire] spends nothing but this device's own time — copying
  /// a model that already shipped inside the app.
  ///
  /// False when it spends the user's network. Airo Mind's two models are about
  /// 570 MB together, and starting that on first launch, unannounced, on
  /// whatever connection happens to be up, is not a default anyone consented
  /// to. `MindService.initialize` reads this to decide whether acquisition may
  /// run by itself or has to be offered; it is on the provider because only
  /// the provider knows what its own bytes cost.
  bool get acquiresWithoutNetwork;

  /// True when every required model is on disk at its pinned size.
  ///
  /// Size, not digest — hashing half a gigabyte on every launch costs about a
  /// second. Full verification is [verify], run after an acquisition.
  Future<bool> isInstalled(Directory modelsDir);

  /// The required models that are not installed.
  ///
  /// On the provider rather than on a caller stat-ing the directory itself: a
  /// provider decides what "installed" means for its own layout, and a caller
  /// that re-implements the check is a copy that goes stale the moment one
  /// does something different.
  Future<List<RequiredModel>> missingModels(Directory modelsDir);

  /// Puts missing models on disk, reporting progress as they arrive.
  Stream<ModelAcquisitionEvent> acquire(Directory modelsDir);

  Future<List<InstalledModel>> verify(Directory modelsDir);

  /// Releases whatever acquiring models holds open, and is called by
  /// `MindService.dispose`.
  ///
  /// On the bundled installer there is nothing to release. A download-backed
  /// provider holds a subscription to the platform download stream and a
  /// progress controller per model — invisible to the shell once the provider
  /// is inside the service, so the service is what has to close it.
  Future<void> dispose();
}

/// The disk half of a [ModelProvider] that keeps models as files in one
/// directory, under the names the registry pins — which is every provider
/// there is, because that is what the Rust engines are handed
/// (`ADR-0018 §1`: a directory and a budget).
///
/// Exists so the pinned-size check is written once. It was previously three
/// copies — one per provider, one in `MindService` — which is how "installed"
/// quietly comes to mean three different things.
mixin PinnedModelFiles implements ModelProvider {
  /// Nothing to release by default: a provider that only reads files holds no
  /// stream open. Overridden by the ones that do.
  @override
  Future<void> dispose() async {}

  @override
  Future<List<RequiredModel>> missingModels(Directory modelsDir) async => [
    for (final model in await requiredModels())
      if (!isPresent(modelsDir, model)) model,
  ];

  @override
  Future<bool> isInstalled(Directory modelsDir) async =>
      (await missingModels(modelsDir)).isEmpty;

  /// Present at its pinned size. Not its pinned digest — see
  /// [ModelProvider.isInstalled] for why hashing is not on the launch path.
  static bool isPresent(Directory modelsDir, RequiredModel model) {
    final file = File(p.join(modelsDir.path, model.fileName));
    return file.existsSync() && file.lengthSync() == model.sizeBytes;
  }
}
