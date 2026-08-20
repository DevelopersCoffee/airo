import 'dart:io';

import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';
import 'package:feature_mind/src/notebook/application/notebook_repository.dart';
import 'package:feature_mind/src/notebook/domain/notebook_document.dart';
import 'package:feature_mind/src/notebook/domain/notebook_source.dart';
import 'package:feature_mind/src/notes/domain/notes_operation_log.dart';
import 'package:feature_mind/src/notes/notes_capability.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late NotebookRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notebook_repo_');
    final log = await NotesOperationLog.open('${tempDir.path}/notes.log');
    repo = NotebookRepository(NotesCapability(log));
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  test('save then all() round-trips tags through the notes log', () async {
    await repo.save(
      id: 'n1',
      title: 'Standup',
      document: const NotebookDocument(
        body: 'pods',
        tags: ['work'],
        labels: ['meeting'],
      ),
      recordedAtMs: 1,
    );

    final notes = await repo.all();
    expect(notes, hasLength(1));
    expect(notes.single.document.tags, ['work']);
    expect(notes.single.document.labels, ['meeting']);
    expect(notes.single.preview, 'pods');
  });

  test('ingestProcessed writes transcript, summary, and key points', () async {
    final note = await repo.ingestProcessed(
      job: const MeetingProcessingJob(
        id: 'job1',
        audioPath: '/tmp/a.m4a',
        title: 'Podcast episode',
        enqueuedAtMs: 10,
        source: MeetingProcessingSource.podcast,
      ),
      transcript: 'We should launch on Tuesday.',
      minutes: '''
# Summary
Launch Tuesday.

## Key points
- Launch on Tuesday
''',
      meetingId: 'm9',
      languageCode: 'en',
    );

    expect(note.document.source, NotebookSource.podcast);
    expect(note.document.meetingId, 'm9');
    expect(note.document.languageCode, 'en');
    expect(note.document.summary, contains('Launch Tuesday'));
    expect(note.document.keyPoints, contains('Launch on Tuesday'));
    expect(note.document.transcript, contains('launch on Tuesday'));
    expect((await repo.all()).single.id, 'note_m9');
  });

  test('superSummary folds two notes into one recap note', () async {
    await repo.save(
      id: 'a',
      title: 'One',
      document: const NotebookDocument(
        summary: 'First thread.',
        keyPoints: ['Do A'],
        tags: ['alpha'],
      ),
      recordedAtMs: 1,
    );
    await repo.save(
      id: 'b',
      title: 'Two',
      document: const NotebookDocument(
        summary: 'Second thread.',
        keyPoints: ['Do B'],
        tags: ['beta'],
      ),
      recordedAtMs: 2,
    );

    final recap = await repo.superSummary(
      notes: await repo.all(),
      recordedAtMs: 3,
    );

    expect(recap.title, 'Super summary · 2 notes');
    expect(recap.document.source, NotebookSource.superSummary);
    expect(recap.document.sourceNoteIds, ['a', 'b']);
    expect(recap.document.tags, containsAll(['alpha', 'beta']));
    expect((await repo.all()), hasLength(3));
  });
}
