import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../runtime/persistent/persistent_operation_log.dart'
    show sharedMindOperationLog;
import '../runtime/ports/operation_log_port.dart';
import '../whisper/api/meetings_seam.dart'
    show embedSpeakerSegment, syncSpeakerEnrollmentJson;
import '../whisper/speaker_enrollment_op_log.dart';
import 'speaker_enrollment_operation_log.dart';

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

/// Durable cross-meeting enrollment — op log + content store (#504).
///
/// SharedPreferences (`mind_global_speaker_enrollment_v1`) is migrated once on
/// first open; new enrollments append to `speaker_enrollment/ops.jsonl`.
class GlobalSpeakerEnrollmentStore {
  GlobalSpeakerEnrollmentStore({
    SharedPreferences? preferences,
    Future<SpeakerEnrollmentOperationLog>? logOpener,
    OperationLogPort? timelineLog,
  }) : _preferences = preferences,
       _logOpener = logOpener,
       _timelineLog = timelineLog ?? sharedMindOperationLog();

  static OperationLogPort sharedTimelineLog() => sharedMindOperationLog();

  static const _legacyStorageKey = 'mind_global_speaker_enrollment_v1';

  SharedPreferences? _preferences;
  final Future<SpeakerEnrollmentOperationLog>? _logOpener;
  final OperationLogPort _timelineLog;
  SpeakerEnrollmentOperationLog? _log;
  bool _migrated = false;

  Future<SharedPreferences> _prefs() async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<SpeakerEnrollmentOperationLog> _ensureLog() async {
    if (_log != null) return _log!;
    if (_logOpener != null) {
      _log = await _logOpener;
    } else {
      final base = await getApplicationSupportDirectory();
      final root = p.join(base.path, 'airo_mind', 'speaker_enrollment');
      _log = await SpeakerEnrollmentOperationLog.open(
        logPath: p.join(root, 'ops.jsonl'),
        contentDirPath: p.join(root, 'content'),
      );
    }
    if (!_migrated) {
      await _migrateLegacyPrefs();
      _migrated = true;
    }
    return _log!;
  }

  Future<void> _migrateLegacyPrefs() async {
    final log = _log!;
    final existing = await log.replay();
    if (existing.isNotEmpty) return;

    final prefs = await _prefs();
    final raw = prefs.getString(_legacyStorageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final entry in decoded.whereType<Map>()) {
        final profile = GlobalEnrolledSpeaker.fromJson(
          entry.cast<String, Object?>(),
        );
        if (profile.id.isEmpty || profile.embedding.isEmpty) continue;
        await log.appendEnroll(
          id: profile.id,
          displayName: profile.displayName,
          embedding: profile.embedding,
          recordedAtMs: now,
        );
      }
      await prefs.remove(_legacyStorageKey);
    } catch (_) {
      // Corrupt legacy blob — leave it; do not block enrollment.
    }
  }

  Future<List<GlobalEnrolledSpeaker>> loadProfiles() async {
    final log = await _ensureLog();
    return await log.projectProfiles();
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

  /// Loads from disk and pushes profiles into the Rust diarizer.
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
    final profile = GlobalEnrolledSpeaker(
      id: id,
      displayName: trimmed,
      embedding: embedding,
    );

    final log = await _ensureLog();
    final now = DateTime.now().millisecondsSinceEpoch;
    await log.appendEnroll(
      id: profile.id,
      displayName: profile.displayName,
      embedding: profile.embedding,
      recordedAtMs: now,
    );
    await _syncRuntime(await log.projectProfiles());
    await appendSpeakerEnrolledOp(
      log: _timelineLog,
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
