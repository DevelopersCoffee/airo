import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_workers/core_workers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/offline_model_info.dart';

/// Bytes above which catalog JSON parse/encode must leave the UI isolate.
const int kHuggingFaceCatalogOffMainThresholdBytes = 50 * 1024;

/// Disk cache of Hugging Face catalog metadata for offline browse.
///
/// Stores previously fetched [OfflineModelInfo] rows (not model weights).
/// A missing file means the catalog was never successfully fetched — callers
/// must surface a clear empty/error state rather than inventing entries.
class HuggingFaceCatalogCache {
  HuggingFaceCatalogCache({
    this.resolveRoot,
    this.fileName = 'hf_catalog_metadata.json',
  });

  final Directory? Function()? resolveRoot;
  final String fileName;

  Future<File> _cacheFile() async {
    final root = resolveRoot?.call() ?? await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'model_catalog'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, fileName));
  }

  /// Whether a non-empty cache file exists from a prior successful fetch.
  Future<bool> hasCachedEntries() async {
    final file = await _cacheFile();
    if (!await file.exists()) return false;
    return (await file.length()) > 2;
  }

  /// Loads cached catalog rows, or an empty list when never fetched / corrupt.
  Future<List<OfflineModelInfo>> load() async {
    final File file;
    try {
      file = await _cacheFile();
    } on Object {
      // Host tests and web have no path_provider plugin.
      return const [];
    }
    if (!await file.exists()) return const [];

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return const [];

    try {
      final decoded = await decodeCatalogJson(bytes);
      final models = <OfflineModelInfo>[];
      for (final raw in decoded) {
        if (raw is! Map) continue;
        models.add(OfflineModelInfo.fromJson(Map<String, dynamic>.from(raw)));
      }
      return models;
    } on Object {
      return const [];
    }
  }

  /// Persists [models] for offline browse of already-seen catalog entries.
  Future<void> save(List<OfflineModelInfo> models) async {
    final file = await _cacheFile();
    final payload = models
        .map((model) => model.toJson())
        .toList(growable: false);
    final encoded = await encodeCatalogJson(payload);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsBytes(encoded, flush: true);
    if (await file.exists()) {
      await file.delete();
    }
    await temporary.rename(file.path);
  }

  /// Clears the cache so the next offline open reports never-fetched.
  Future<void> clear() async {
    final file = await _cacheFile();
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Decode catalog JSON, offloading when the payload exceeds ~50 KB.
Future<List<dynamic>> decodeCatalogJson(Uint8List bytes) async {
  if (bytes.lengthInBytes > kHuggingFaceCatalogOffMainThresholdBytes) {
    return runOffMain(() => _decodeCatalogJsonSync(bytes));
  }
  return _decodeCatalogJsonSync(bytes);
}

/// Decode a JSON object or list payload (model card or listing).
Future<Object?> decodeCatalogJsonObject(Uint8List bytes) async {
  if (bytes.lengthInBytes > kHuggingFaceCatalogOffMainThresholdBytes) {
    return runOffMain(() => jsonDecode(utf8.decode(bytes)));
  }
  return jsonDecode(utf8.decode(bytes));
}

List<dynamic> _decodeCatalogJsonSync(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(bytes));
  if (decoded is List) return decoded;
  if (decoded is Map && decoded['models'] is List) {
    return decoded['models'] as List<dynamic>;
  }
  return const [];
}

/// Encode catalog JSON, offloading when the payload exceeds ~50 KB.
Future<Uint8List> encodeCatalogJson(List<Map<String, dynamic>> models) async {
  if (models.isEmpty) {
    return Uint8List.fromList(utf8.encode('{"version":1,"models":[]}'));
  }
  // Prefer leaving the UI isolate before a large encode, not after.
  if (models.length >= 8) {
    return runOffMain(() => _encodeCatalogJsonSync(models));
  }
  final encoded = _encodeCatalogJsonSync(models);
  if (encoded.lengthInBytes > kHuggingFaceCatalogOffMainThresholdBytes) {
    return runOffMain(() => _encodeCatalogJsonSync(models));
  }
  return encoded;
}

Uint8List _encodeCatalogJsonSync(List<Map<String, dynamic>> models) {
  final json = jsonEncode({'version': 1, 'models': models});
  return Uint8List.fromList(utf8.encode(json));
}
