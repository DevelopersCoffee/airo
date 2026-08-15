import 'dart:convert';
import 'dart:io';

import '../domain/meeting_processing_job.dart';

/// Where `MeetingProcessingQueue` persists its job list, so it survives an
/// app restart (#1656 AC4).
///
/// Kept as an interface — not just a `File` inline in the queue — for the
/// same reason `AudioRecorderPort` and `MeetingRecordingServiceGateway` are:
/// a fake in-memory store lets the queue's resume-after-restart behaviour be
/// asserted in a test without touching a real filesystem.
abstract interface class MeetingProcessingQueueStore {
  Future<List<MeetingProcessingJob>> load();

  Future<void> save(List<MeetingProcessingJob> jobs);
}

/// Real persistence: one JSON file under the app's support directory.
///
/// A flat file rather than a database because the whole payload is small
/// (a handful of pending meetings at most — this is not an event log) and
/// the read/write pattern is "load everything once at startup, rewrite
/// everything on every mutation", which a single JSON array serves fine.
class FileMeetingProcessingQueueStore implements MeetingProcessingQueueStore {
  const FileMeetingProcessingQueueStore(this.filePath);

  final String filePath;

  @override
  Future<List<MeetingProcessingJob>> load() async {
    final file = File(filePath);
    if (!file.existsSync()) return const [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return const [];
    final decoded = jsonDecode(raw) as List<Object?>;
    return decoded
        .map((e) => MeetingProcessingJob.fromJson(e! as Map<String, Object?>))
        .toList(growable: false);
  }

  @override
  Future<void> save(List<MeetingProcessingJob> jobs) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final encoded = jsonEncode(jobs.map((j) => j.toJson()).toList());
    // Write to a sibling temp file and rename, so a process death mid-write
    // never leaves the queue file half-written and unparsable on the next
    // launch — the failure mode this whole store exists to survive.
    final tmp = File('$filePath.tmp');
    await tmp.writeAsString(encoded, flush: true);
    await tmp.rename(filePath);
  }
}
