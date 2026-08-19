import 'dart:io';

import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

/// Cheap on-disk checks before advertising a GGUF row as runnable.
class GgufArtifactGuard {
  const GgufArtifactGuard._();

  static bool isVerified(OfflineModelInfo model) {
    if (kIsWeb) return false;
    final path = model.filePath?.trim();
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    if (!file.existsSync()) return false;
    if (model.fileSizeBytes <= 0) return true;
    return file.lengthSync() == model.fileSizeBytes;
  }

  static ({int expected, int found})? sizeMismatch(OfflineModelInfo model) {
    final path = model.filePath?.trim();
    if (path == null || path.isEmpty || model.fileSizeBytes <= 0) {
      return null;
    }
    final file = File(path);
    if (!file.existsSync()) return null;
    final found = file.lengthSync();
    if (found == model.fileSizeBytes) return null;
    return (expected: model.fileSizeBytes, found: found);
  }
}
