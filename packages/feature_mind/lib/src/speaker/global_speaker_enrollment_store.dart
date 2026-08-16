import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../whisper/api/meetings_seam.dart' show embedSpeakerSegment, syncSpeakerEnrollmentJson;

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

/// Durable cross-meeting enrollment scaffold — syncs embeddings to Rust (#504).
class GlobalSpeakerEnrollmentStore {
  GlobalSpeakerEnrollmentStore([SharedPreferences? preferences])
    : _preferences = preferences;

  static const _storageKey = 'mind_global_speaker_enrollment_v1';

  SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<List<GlobalEnrolledSpeaker>> loadProfiles() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((entry) => GlobalEnrolledSpeaker.fromJson(entry.cast<String, Object?>()))
          .where((profile) => profile.id.isNotEmpty && profile.embedding.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveProfiles(List<GlobalEnrolledSpeaker> profiles) async {
    final prefs = await _prefs();
    await prefs.setString(
      _storageKey,
      jsonEncode(profiles.map((profile) => profile.toJson()).toList()),
    );
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

  /// Loads from disk and pushes profiles into the Rust diarizer.
  Future<void> syncToRuntime() async {
    final profiles = await loadProfiles();
    await saveProfiles(profiles);
  }

  /// Enrolls a speaker from one meeting segment (#504).
  ///
  /// Returns the saved profile, or null when embedding could not be computed.
  Future<GlobalEnrolledSpeaker?> enrollFromSegment({
    required String displayName,
    required String wavPath,
    required int startMs,
    required int endMs,
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
    final profile = GlobalEnrolledSpeaker(
      id: id,
      displayName: trimmed,
      embedding: embedding,
    );
    final next = [...profiles, profile];
    await saveProfiles(next);
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
