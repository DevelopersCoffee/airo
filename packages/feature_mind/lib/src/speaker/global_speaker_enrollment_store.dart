import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/persistent/persistent_operation_log.dart'
    show sharedMindOperationLog;
import '../whisper/api/meetings_seam.dart'
    show embedSpeakerSegment, syncSpeakerEnrollmentJson;
import '../whisper/api/mind_runtime.dart'
    show mindRuntimeEnrollSpeaker, mindRuntimeSpeakerProfilesJson;
import '../whisper/speaker_enrollment_op_log.dart' show appendSpeakerEnrolledOp;

/// A globally enrolled speaker profile (#504) — survives across meetings.
class GlobalEnrolledSpeaker {
  const GlobalEnrolledSpeaker({
    required this.id,
    required this.displayName,
    required this.embedding,
  });

  final String id;
  final String displayName;
  final List<double> embedding;

  Map<String, Object?> toJson() => {
    'id': id,
    'displayName': displayName,
    'embedding': embedding,
  };

  factory GlobalEnrolledSpeaker.fromJson(Map<String, Object?> json) =>
      GlobalEnrolledSpeaker(
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        embedding: (json['embedding'] as List?)
                ?.map((value) => (value as num).toDouble())
                .toList(growable: false) ??
            const [],
      );
}

/// Vault-encrypted cross-meeting enrollment via Rust operation log (#504).
///
/// Legacy SharedPreferences (`mind_global_speaker_enrollment_v1`) and Dart
/// `speaker_enrollment/ops.jsonl` are migrated into Rust on first boot.
class GlobalSpeakerEnrollmentStore {
  GlobalSpeakerEnrollmentStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _legacyStorageKey = 'mind_global_speaker_enrollment_v1';

  SharedPreferences? _preferences;
  bool _legacyPrefsMigrated = false;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> _migrateLegacyPrefsIfNeeded() async {
    if (_legacyPrefsMigrated) return;
    _legacyPrefsMigrated = true;

    final existing = await loadProfiles();
    if (existing.isNotEmpty) return;

    final prefs = await _prefs();
    final raw = prefs.getString(_legacyStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      for (final entry in decoded.whereType<Map>()) {
        final profile = GlobalEnrolledSpeaker.fromJson(
          entry.cast<String, Object?>(),
        );
        if (profile.id.isEmpty || profile.embedding.isEmpty) continue;
        mindRuntimeEnrollSpeaker(
          id: profile.id,
          displayName: profile.displayName,
          embedding: profile.embedding,
        );
      }
      await prefs.remove(_legacyStorageKey);
    } catch (_) {
      // Corrupt legacy blob — leave it; do not block enrollment.
    }
  }

  Future<List<GlobalEnrolledSpeaker>> loadProfiles() async {
    await _migrateLegacyPrefsIfNeeded();
    try {
      final raw = mindRuntimeSpeakerProfilesJson();
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map(
            (entry) => GlobalEnrolledSpeaker.fromJson(
              entry.cast<String, Object?>(),
            ),
          )
          .where(
            (profile) =>
                profile.id.isNotEmpty && profile.embedding.isNotEmpty,
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _syncRuntime(List<GlobalEnrolledSpeaker> profiles) async {
    syncSpeakerEnrollmentJson(
      profiles
          .map(
            (profile) => {
              'id': profile.id,
              'display_name': profile.displayName,
              'embedding': profile.embedding,
            },
          )
          .toList(growable: false),
    );
  }

  /// Loads from Rust and pushes profiles into the diarizer.
  Future<void> syncToRuntime() async {
    final profiles = await loadProfiles();
    await _syncRuntime(profiles);
  }

  /// Enrolls a speaker from one meeting segment (#504).
  ///
  /// Returns the saved profile, or null when embedding could not be computed.
  Future<GlobalEnrolledSpeaker?> enrollFromSegment({
    required String displayName,
    required String wavPath,
    required int startMs,
    required int endMs,
    String timelineContextId = '',
  }) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return null;
    final embedding = embedSpeakerSegment(
      wavPath: wavPath,
      startMs: startMs,
      endMs: endMs,
    );
    if (embedding.isEmpty) return null;

    final profiles = await loadProfiles();
    final id = _nextEnrolledId(profiles);
    try {
      mindRuntimeEnrollSpeaker(
        id: id,
        displayName: trimmed,
        embedding: embedding,
      );
    } on Object {
      return null;
    }

    final profile = GlobalEnrolledSpeaker(
      id: id,
      displayName: trimmed,
      embedding: embedding,
    );

    await appendSpeakerEnrolledOp(
      log: sharedMindOperationLog(),
      profileId: profile.id,
      displayName: profile.displayName,
      contextId: timelineContextId,
    );

    return profile;
  }

  String _nextEnrolledId(List<GlobalEnrolledSpeaker> profiles) {
    var max = -1;
    for (final profile in profiles) {
      final suffix = profile.id.startsWith('enrolled_')
          ? profile.id.substring('enrolled_'.length)
          : null;
      final parsed = suffix != null ? int.tryParse(suffix) : null;
      if (parsed != null && parsed > max) {
        max = parsed;
      }
    }
    return 'enrolled_${max + 1}';
  }
}
