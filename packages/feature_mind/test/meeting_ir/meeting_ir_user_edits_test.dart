import 'package:feature_mind/src/meeting_ir/meeting_ir_user_edits.dart';
import 'package:feature_mind/src/whisper/api/meetings.dart' as rust;
import 'package:flutter_test/flutter_test.dart';

void main() {
  const item = rust.MeetingActionItemRecord(
    id: 'a1',
    task: 'Ship pods',
    owner: 'Priya',
    status: rust.MeetingActionStatus.open,
    evidenceSegmentIds: ['s0'],
  );

  test('display helpers prefer user edits over IR', () {
    final edits = const MeetingIrUserEdits().upsert(
      'a1',
      const MeetingActionUserEdit(task: 'Ship three pods', owner: 'Dev'),
    );
    expect(edits.taskFor(item), 'Ship three pods');
    expect(edits.ownerFor(item), 'Dev');
  });

  test('empty-string owner clears the IR owner', () {
    final edits = const MeetingIrUserEdits().upsert(
      'a1',
      const MeetingActionUserEdit(owner: ''),
    );
    expect(edits.ownerFor(item), isNull);
    expect(edits.taskFor(item), 'Ship pods');
  });

  test('round-trips through JSON without dropping edits', () {
    final edits = const MeetingIrUserEdits().upsert(
      'a1',
      const MeetingActionUserEdit(task: 'Fixed', owner: 'Sam'),
    );
    final again = MeetingIrUserEdits.decode(edits.encode());
    expect(again.taskFor(item), 'Fixed');
    expect(again.ownerFor(item), 'Sam');
  });

  test('re-extraction with same action id keeps user edits', () {
    // Simulated: extraction rewrote task text on the Meeting record, but the
    // user edit overlay still wins on display.
    final edits = const MeetingIrUserEdits().upsert(
      'a1',
      const MeetingActionUserEdit(task: 'User correction'),
    );
    const reextracted = rust.MeetingActionItemRecord(
      id: 'a1',
      task: 'Model said something else',
      owner: 'Priya',
      status: rust.MeetingActionStatus.open,
      evidenceSegmentIds: ['s0'],
    );
    expect(edits.taskFor(reextracted), 'User correction');
  });
}
