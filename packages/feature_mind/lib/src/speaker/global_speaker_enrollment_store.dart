import 'dart:convert';

import '../runtime/persistent/persistent_operation_log.dart'
    show sharedMindOperationLog;
import '../whisper/api/meetings_seam.dart' show embedSpeakerSegment;
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
class GlobalSpeakerEnrollmentStore {
  GlobalSpeakerEnrollmentStore();

  Future<List<GlobalEnrolledSpeaker>> loadProfiles() async {
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

  Future<void> syncToRuntime() async {
    await loadProfiles();
  }

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
