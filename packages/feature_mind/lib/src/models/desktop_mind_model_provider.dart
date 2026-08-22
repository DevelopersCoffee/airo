import 'dart:io';

import 'package:path/path.dart' as p;

import '../model_installer.dart';
import 'model_descriptor_adapter.dart' as descriptors;
import 'model_provider.dart';

/// Bundled-model install for desktop Mind shells.
///
/// `platform_downloads` is mobile-only (Android/iOS). On macOS/Linux/Windows
/// the standalone Mind app copies pinned weights from the dev asset cache
/// (`app/tool/fetch_mind_models.sh`) or downloads them over HTTP when the
/// sandbox cannot read the checkout.
class DesktopMindModelProvider extends ModelInstaller {
  const DesktopMindModelProvider({
    this.includeMultilingual = true,
    this.downloadUrlFor,
  });

  final bool includeMultilingual;

  /// Same hosting map the mobile shell passes to [DownloadModelProvider].
  final String? Function(RequiredModel model)? downloadUrlFor;

  @override
  Future<List<RequiredModel>> requiredModels() => descriptors
      .mindScribeRequiredModels(includeMultilingual: includeMultilingual);

  @override
  Future<List<String>> install(
    Directory modelsDir, {
    void Function(String fileName, int copied, int total)? onProgress,
  }) async {
    final failed = await super.install(modelsDir, onProgress: onProgress);
    if (failed.isEmpty || downloadUrlFor == null) return failed;

    final requiredByName = {
      for (final model in await requiredModels()) model.fileName: model,
    };

    final stillFailed = <String>[];
    for (final fileName in failed) {
      final required = requiredByName[fileName];
      final url = required == null ? null : downloadUrlFor!(required);
      if (required == null || url == null || url.isEmpty) {
        stillFailed.add(fileName);
        continue;
      }

      final ok = await _downloadPinnedModel(
        modelsDir: modelsDir,
        required: required,
        url: url,
        onProgress: onProgress,
      );
      if (!ok) stillFailed.add(fileName);
    }
    return stillFailed;
  }

  Future<bool> _downloadPinnedModel({
    required Directory modelsDir,
    required RequiredModel required,
    required String url,
    void Function(String fileName, int copied, int total)? onProgress,
  }) async {
    final target = File(p.join(modelsDir.path, required.fileName));
    if (PinnedModelFiles.isPresent(modelsDir, required)) return true;

    final partial = File('${target.path}.partial');
    if (target.existsSync()) {
      try {
        target.deleteSync();
      } on Object {
        return false;
      }
    }
    if (partial.existsSync()) {
      try {
        partial.deleteSync();
      } on Object {
        // Best-effort; a fresh download recreates the partial.
      }
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }

      final sink = partial.openWrite();
      var copied = 0;
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          copied += chunk.length;
          onProgress?.call(required.fileName, copied, required.sizeBytes);
        }
      } finally {
        await sink.close();
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
          // Best-effort cleanup.
        }
      }
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
