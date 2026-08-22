import 'package:core_workers/core_workers.dart';

import '../../capture/domain/meeting_processing_job.dart';
import '../../notes/domain/note.dart';
import '../../notes/notes_capability.dart';
import '../domain/key_points_extractor.dart';
import '../domain/notebook_document.dart';
import '../domain/notebook_note.dart';
import '../domain/notebook_source.dart';
import '../domain/notebook_summary.dart';
import '../domain/super_summary.dart';

/// Application seam over [NotesCapability]: encode/decode notebook documents
/// without giving the capability a second store (`C5` / `I4`).
class NotebookRepository {
  NotebookRepository(
    this._capability, {
    this.extractor = const KeyPointsExtractor(),
    this.composer = const SuperSummaryComposer(),
  });

  final NotesCapability _capability;
  final KeyPointsExtractor extractor;
  final SuperSummaryComposer composer;

  static const _offMainThresholdChars = 50 * 1024;

  Future<List<NotebookNote>> all() async {
    final projection = await _capability.notes();
    return [for (final note in projection.all) await _read(note)];
  }

  Future<NotebookNote?> get(String id) async {
    final projection = await _capability.notes();
    final note = projection.get(id);
    if (note == null) return null;
    return _read(note);
  }

  Future<NotebookNote> save({
    required String id,
    required String title,
    required NotebookDocument document,
    required int recordedAtMs,
    bool exists = false,
  }) async {
    final body = await _encode(document);
    if (exists) {
      await _capability.editNote(
        id: id,
        title: title,
        body: body,
        recordedAtMs: recordedAtMs,
      );
    } else {
      await _capability.createNote(
        id: id,
        title: title,
        body: body,
        recordedAtMs: recordedAtMs,
      );
    }
    return NotebookNote(
      note: Note(id: id, title: title, body: body, updatedAtMs: recordedAtMs),
      document: document,
    );
  }

  Future<void> delete({required String id, required int recordedAtMs}) {
    return _capability.deleteNote(id: id, recordedAtMs: recordedAtMs);
  }

  /// Turns a finished transcription job into a durable notebook note.
  Future<NotebookNote> ingestProcessed({
    required MeetingProcessingJob job,
    required String transcript,
    required String minutes,
    String? meetingId,
    String? languageCode,
    List<String> actionItems = const [],
    int? recordedAtMs,
  }) {
    final document = NotebookDocument(
      transcript: transcript,
      summary: NotebookSummary.fromMinutes(
        minutes.trim().isNotEmpty ? minutes : transcript,
      ),
      keyPoints: extractor.extract(
        minutes: minutes,
        transcript: transcript,
        actionItems: actionItems,
      ),
      languageCode: languageCode,
      source: NotebookSource.fromProcessingSource(job.source.name),
      meetingId: meetingId,
      audioPath: job.audioPath,
      labels: const ['transcript'],
    );
    final id = 'note_${meetingId ?? job.id}';
    return save(
      id: id,
      title: job.title,
      document: document,
      recordedAtMs: recordedAtMs ?? job.enqueuedAtMs,
    );
  }

  Future<NotebookNote> superSummary({
    required List<NotebookNote> notes,
    required int recordedAtMs,
    String? generatedRecap,
    String? title,
  }) {
    if (notes.length < 2) {
      throw ArgumentError('Super Summary needs at least two notes');
    }
    final document = composer.compose(
      notes: notes,
      generatedRecap: generatedRecap,
    );
    return save(
      id: 'note_super_$recordedAtMs',
      title: title ?? composer.defaultTitle(notes),
      document: document,
      recordedAtMs: recordedAtMs,
    );
  }

  Future<NotebookNote> _read(Note note) async {
    if (note.body.length > _offMainThresholdChars) {
      final document = await runOffMain(
        () => NotebookDocument.decode(note.body),
      );
      return NotebookNote(note: note, document: document);
    }
    return NotebookNote.fromNote(note);
  }

  Future<String> _encode(NotebookDocument document) async {
    final encoded = document.encode();
    if (encoded.length > _offMainThresholdChars) {
      return runOffMain(document.encode);
    }
    return encoded;
  }
}
