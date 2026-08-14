import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

/// A meeting's embedding vector, and which model produced it.
///
/// Storing the model id alongside the vector mirrors `MeetingRecord.model`
/// (`ADR-0018 §5`): what produced a piece of derived content is recorded,
/// not inferred later. If the embedding model changes, a caller compares
/// [modelId] against the currently-resolved model and knows this vector is
/// stale — [MeetingEmbeddingStore] itself does not judge staleness, it only
/// reports what is on disk.
@immutable
class StoredEmbedding {
  const StoredEmbedding({required this.modelId, required this.vector});

  final String modelId;
  final List<double> vector;
}

/// Persists one embedding vector per meeting, keyed by meeting id.
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
class MeetingEmbeddingStore {
  MeetingEmbeddingStore(this._dir);

  final Directory _dir;

  File get _file => File(p.join(_dir.path, 'meeting_embeddings.json'));

  /// Stores [vector] for [meetingId], produced by [modelId]. Overwrites
  /// whatever was stored for that meeting before.
  Future<void> put(
    String meetingId,
    String modelId,
    List<double> vector,
  ) async {
    final data = await _readAll();
    data[meetingId] = {'modelId': modelId, 'vector': vector};
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
    final vector = raw['vector'];
    if (modelId is! String || vector is! List) return null;
    return StoredEmbedding(
      modelId: modelId,
      vector: vector.cast<num>().map((v) => v.toDouble()).toList(),
    );
  }

  Future<Map<String, dynamic>> _readAll() async {
    if (!await _file.exists()) return {};
    final content = await _file.readAsString();
    if (content.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(content);
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
    await _file.writeAsString(jsonEncode(data));
  }
}
