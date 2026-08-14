import 'dart:io';

import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('notes_vertical_slice_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// The single most important test in `#1338`: create a note, confirm it is
  /// durable, wipe the in-memory projection, replay the persisted
  /// operations, and confirm the rebuilt projection is identical to what
  /// existed before the wipe. `C4`'s "delete and rebuild with zero data
  /// loss" and condition 5 of `#1311`, proven rather than asserted by
  /// comment -- the Dart twin of
  /// `airo_mind_core::notes::tests::a_note_survives_projection_deletion_and_replay`.
  test('a note survives projection deletion and replay', () async {
    final log = await NotesOperationLog.open('${tempDir.path}/notes.log');
    final capability = NotesCapability(log);

    await capability.createNote(
      id: 'n1',
      title: 'Groceries',
      body: 'milk, eggs',
      recordedAtMs: 1000,
    );
    await capability.createNote(
      id: 'n2',
      title: 'Throwaway',
      body: 'delete me',
      recordedAtMs: 2000,
    );
    await capability.editNote(
      id: 'n1',
      title: 'Groceries',
      body: 'milk, eggs, bread',
      recordedAtMs: 3000,
    );
    await capability.deleteNote(id: 'n2', recordedAtMs: 4000);

    // 1. Confirm persisted: the log itself, independent of any projection,
    //    holds every operation.
    expect(await log.count(), 4);

    // 2. The projection before the wipe.
    final before = await capability.notes();
    expect(before.length, 1, reason: 'n2 was deleted, only n1 should remain');
    final n1Before = before.get('n1')!;
    expect(n1Before.title, 'Groceries');
    expect(n1Before.body, 'milk, eggs, bread');
    expect(before.get('n2'), isNull);

    // 3. "Wipe" the in-memory projection: nothing after this line reads
    //    `before` again. `NotesCapability` itself holds no cache to fall
    //    back on (`I2`, `I4`) -- the only durable copy is the log.

    // 4. Replay from persisted operations and rebuild.
    final ops = await log.replay();
    final after = NotesProjection.rebuild(ops);

    // 5. Zero data loss: identical state.
    expect(after.get('n1'), n1Before);
    expect(after.length, 1);
    expect(after.get('n2'), isNull);
    expect(after, before);

    // Also identical through the capability's own read path.
    final viaCapability = await capability.notes();
    expect(viaCapability, after);
  });

  test(
    'replay visits every notes operation exactly once, and rebuild is idempotent',
    () async {
      final log = await NotesOperationLog.open('${tempDir.path}/notes.log');
      final capability = NotesCapability(log);

      for (var i = 0; i < 25; i++) {
        await capability.createNote(
          id: 'n$i',
          title: 'title $i',
          body: 'body',
          recordedAtMs: i,
        );
      }

      final ops = await log.replay();
      expect(ops.length, 25);

      final first = NotesProjection.rebuild(ops);
      final second = NotesProjection.rebuild(ops);
      expect(first, second);
      expect(first.length, 25);
    },
  );

  test('reopening the log resumes sequence numbering', () async {
    final path = '${tempDir.path}/notes.log';
    {
      final log = await NotesOperationLog.open(path);
      await log.append(kind: NoteOpKind.create, id: 'a', recordedAtMs: 1);
      await log.append(kind: NoteOpKind.create, id: 'b', recordedAtMs: 2);
    }
    final reopened = await NotesOperationLog.open(path);
    final third = await reopened.append(
      kind: NoteOpKind.create,
      id: 'c',
      recordedAtMs: 3,
    );
    expect(third.seq, 2, reason: 'sequence numbering must survive a restart');
  });

  test('a torn tail is treated as the end of the durable log', () async {
    final path = '${tempDir.path}/notes.log';
    final log = await NotesOperationLog.open(path);
    await log.append(
      kind: NoteOpKind.create,
      id: 'whole',
      title: 'Whole record',
      recordedAtMs: 1,
    );

    // Simulate a crash mid-write: append a partial JSON line with no
    // trailing newline.
    final file = File(path);
    await file.writeAsString('{"seq":1,"kind":"cre', mode: FileMode.append);

    final recovered = await NotesOperationLog.open(path);
    final ops = await recovered.replay();
    expect(ops.length, 1);
    expect(ops.first.id, 'whole');
  });

  test('empty log replays to nothing', () async {
    final log = await NotesOperationLog.open('${tempDir.path}/notes.log');
    expect(await log.replay(), isEmpty);
    expect(NotesProjection.rebuild(const []), NotesProjection.empty);
  });
}
