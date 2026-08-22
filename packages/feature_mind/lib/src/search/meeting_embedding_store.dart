import 'dart:convert';
import 'dart:io';

import 'package:core_workers/core_workers.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A meeting's embedding vector(s), and which model produced them.
///
/// Storing the model id alongside the vectors mirrors `MeetingRecord.model`
/// (`ADR-0018 §5`): what produced a piece of derived content is recorded,
/// not inferred later. If the embedding model changes, a caller compares
/// [modelId] against the currently-resolved model and knows these vectors
/// are stale — [MeetingEmbeddingStore] itself does not judge staleness, it
/// only reports what is on disk.
///
/// [vectors] is one entry per text chunk (see `MeetingTextChunker`). A
/// single-element list is the common short-meeting case and also the shape
/// read back from stores written before chunking landed.
@immutable
class StoredEmbedding {
  const StoredEmbedding({required this.modelId, required this.vectors})
    : assert(vectors.length > 0);

  final String modelId;

  /// One embedding per chunk, in chunk order. Never empty.
  final List<List<double>> vectors;

  /// Convenience for the single-vector / legacy shape.
  List<double> get vector => vectors.first;
}

/// Persists embedding vectors per meeting, keyed by meeting id.
///
/// A flat JSON file, not a database: meeting counts for a personal scribe
/// are expected in the hundreds, and `feature_mind` has no Drift/sqflite
/// dependency today (`docs/superpowers/specs/2026-08-09-mind-scribe-semantic-search.md`)
/// — introducing one for a single small map is weight this doesn't need
/// unless that assumption is ever proven wrong.
///
/// Lives in the same directory `MindService.modelsDirectory()` already uses
/// for models and the meeting store, rather than inventing a second
/// location — the caller passes that `Directory` in, this class does not
/// resolve it itself.
///
/// JSON decode/encode over ~50 KB runs via [runOffMain] — each 768-d vector
/// is already ~10 KB of JSON, so a modest archive crosses the repo's
/// main-isolate parsing rule quickly.
class MeetingEmbeddingStore {
  MeetingEmbeddingStore(this._dir);

  final Directory _dir;

  static const _offMainBytes = 50 * 1024;

  File get _file => File(p.join(_dir.path, 'meeting_embeddings.json'));

  /// Stores a single [vector] for [meetingId], produced by [modelId].
  /// Overwrites whatever was stored for that meeting before.
  Future<void> put(String meetingId, String modelId, List<double> vector) =>
      putChunks(meetingId, modelId, [vector]);

  /// Stores one vector per chunk for [meetingId]. [chunkVectors] must be
  /// non-empty — call [remove] to clear instead of writing an empty list.
  Future<void> putChunks(
    String meetingId,
    String modelId,
    List<List<double>> chunkVectors,
  ) async {
    if (chunkVectors.isEmpty) {
      throw ArgumentError.value(
        chunkVectors,
        'chunkVectors',
        'Use remove() to clear; an empty chunk list is not a valid store write.',
      );
    }
    final data = await _readAll();
    data[meetingId] = {
      'modelId': modelId,
      'vectors': chunkVectors,
      // Legacy single-vector field kept so older readers (and hand-inspected
      // JSON) still see a useful primary vector.
      'vector': chunkVectors.first,
    };
    await _writeAll(data);
  }

  /// The stored embedding for [meetingId], or null if none exists.
  Future<StoredEmbedding?> get(String meetingId) async {
    final data = await _readAll();
    return _decode(data[meetingId]);
  }

  /// Drops the stored embedding for [meetingId], if any. A no-op when none
  /// is stored.
  ///
  /// `ADR-0022 §5/§6`: unlike [SearchIndex] (`rust/airo_mind_core/src/
  /// search.rs`), this store is not rebuilt from `MeetingStore` on boot --
  /// it is a plain read/write-through cache, so once IR text (decision
  /// statements, action-item owners) flows into it via
  /// `SemanticSearchRanker`, that vector persists indefinitely unless
  /// something explicitly clears it. Nothing calls this yet: no meeting
  /// deletion mechanism exists today (#1719). It exists so that mechanism,
  /// whenever it lands, only has to call [remove], not build it.
  Future<void> remove(String meetingId) async {
    final data = await _readAll();
    if (data.remove(meetingId) == null) return;
    await _writeAll(data);
  }

  /// Every stored embedding, keyed by meeting id.
  Future<Map<String, StoredEmbedding>> all() async {
    final data = await _readAll();
    final result = <String, StoredEmbedding>{};
    for (final entry in data.entries) {
      final decoded = _decode(entry.value);
      if (decoded != null) result[entry.key] = decoded;
    }
    return result;
  }

  StoredEmbedding? _decode(Object? raw) {
    if (raw is! Map) return null;
    final modelId = raw['modelId'];
    if (modelId is! String) return null;

    final vectorsRaw = raw['vectors'];
    if (vectorsRaw is List && vectorsRaw.isNotEmpty) {
      final vectors = <List<double>>[];
      for (final item in vectorsRaw) {
        if (item is! List) return null;
        vectors.add(item.cast<num>().map((v) => v.toDouble()).toList());
      }
      return StoredEmbedding(modelId: modelId, vectors: vectors);
    }

    // Pre-chunking schema: a single `vector` field.
    final vector = raw['vector'];
    if (vector is! List) return null;
    return StoredEmbedding(
      modelId: modelId,
      vectors: [vector.cast<num>().map((v) => v.toDouble()).toList()],
    );
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (!await _file.exists()) return {};
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return {};
    try {
      final decoded = content.length > _offMainBytes
          ? await runOffMain(() => jsonDecode(content))
          : jsonDecode(content);
      return decoded is Map<String, dynamic> ? decoded : {};
    } on FormatException {
      // A corrupt file degrades to "nothing stored yet," the same as a
      // fresh install -- re-embedding is cheap and local; refusing to start
      // over it is not a kindness.
      return {};
    }
  }

  Future<void> _writeAll(Map<String, dynamic> data) async {
    if (!await _dir.exists()) await _dir.create(recursive: true);
    final encoded = _estimateEncodedBytes(data) > _offMainBytes
        ? await runOffMain(() => jsonEncode(data))
        : jsonEncode(data);
    await _file.writeAsString(encoded);
  }

  /// Rough JSON size before encoding: each float ~12 chars plus key overhead.
  /// Prefer overshooting into [runOffMain] over decoding hundreds of KB on
  /// the UI isolate.
  int _estimateEncodedBytes(Map<String, dynamic> data) {
    var estimate = 2;
    for (final entry in data.entries) {
      estimate += entry.key.length + 16;
      final value = entry.value;
      if (value is! Map) continue;
      final vectors = value['vectors'];
      if (vectors is List) {
        for (final vector in vectors) {
          if (vector is List) estimate += vector.length * 12 + 8;
        }
        estimate += 64;
        continue;
      }
      if (value['vector'] is List) {
        estimate += (value['vector'] as List).length * 12 + 64;
      }
    }
    return estimate;
  }
}
