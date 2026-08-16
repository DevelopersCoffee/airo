import 'dart:convert';
import 'dart:io';

import 'speaker_enrollment_content_store.dart';
import 'speaker_enrollment_operation.dart';
import 'global_speaker_enrollment_store.dart';

/// Append-only enrollment log — durable cross-meeting speaker profiles (#504).
///
/// Twin of [NotesOperationLog]: replay builds the enrolled profile projection
/// until Rust #1213 owns the operation log.
class SpeakerEnrollmentOperationLog {
  SpeakerEnrollmentOperationLog._(this._file, this._content);

  final File _file;
  final SpeakerEnrollmentContentStore _content;
  int _nextSeq = 0;

  static Future<SpeakerEnrollmentOperationLog> open({
    required String logPath,
    required String contentDirPath,
  }) async {
    final file = File(logPath);
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    if (!await file.exists()) {
      await file.create(recursive: true);
    }
    final content = await SpeakerEnrollmentContentStore.open(contentDirPath);
    final log = SpeakerEnrollmentOperationLog._(file, content);
    final existing = await log.replay();
    log._nextSeq = existing.isEmpty ? 0 : existing.last.seq + 1;
    return log;
  }

  SpeakerEnrollmentContentStore get contentStore => _content;

  Future<SpeakerEnrollmentOperation> appendEnroll({
    required String id,
    required String displayName,
    required List<double> embedding,
    required int recordedAtMs,
  }) async {
    await _content.put(id, embedding);
    return await _append(
      kind: SpeakerEnrollmentOpKind.enroll,
      id: id,
      displayName: displayName,
      recordedAtMs: recordedAtMs,
    );
  }

  Future<SpeakerEnrollmentOperation> appendRemove({
    required String id,
    required int recordedAtMs,
  }) async {
    await _content.remove(id);
    return await _append(
      kind: SpeakerEnrollmentOpKind.remove,
      id: id,
      displayName: '',
      recordedAtMs: recordedAtMs,
    );
  }

  Future<SpeakerEnrollmentOperation> _append({
    required SpeakerEnrollmentOpKind kind,
    required String id,
    required String displayName,
    required int recordedAtMs,
  }) async {
    final op = SpeakerEnrollmentOperation(
      seq: _nextSeq++,
      kind: kind,
      id: id,
      displayName: displayName,
      recordedAtMs: recordedAtMs,
    );
    final raf = await _file.open(mode: FileMode.writeOnlyAppend);
    try {
      await raf.writeString('${jsonEncode(op.toJson())}\n');
      await raf.flush();
    } finally {
      await raf.close();
    }
    return op;
  }

  Future<List<SpeakerEnrollmentOperation>> replay() async {
    if (!await _file.exists()) return const [];
    final lines = await _file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .toList();

    final ops = <SpeakerEnrollmentOperation>[];
    for (final line in lines) {
      if (line.isEmpty) continue;
      try {
        final json = jsonDecode(line) as Map<String, Object?>;
        ops.add(SpeakerEnrollmentOperation.fromJson(json));
      } on FormatException {
        break;
      }
    }
    return ops;
  }

  Future<List<GlobalEnrolledSpeaker>> projectProfiles() async {
    final ops = await replay();
    final byId = <String, GlobalEnrolledSpeaker>{};
    for (final op in ops) {
      switch (op.kind) {
        case SpeakerEnrollmentOpKind.enroll:
          final embedding = await _content.get(op.id);
          if (embedding == null || embedding.isEmpty) continue;
          byId[op.id] = GlobalEnrolledSpeaker(
            id: op.id,
            displayName: op.displayName,
            embedding: embedding,
          );
        case SpeakerEnrollmentOpKind.remove:
          byId.remove(op.id);
      }
    }
    return byId.values.toList(growable: false);
  }
}
