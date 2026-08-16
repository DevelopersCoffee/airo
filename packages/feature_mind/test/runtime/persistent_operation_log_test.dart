import 'dart:io';

import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/persistent/persistent_operation_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('persistent_op_log_test_');
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('append persists and replays meetingIrExtracted', () async {
    final path = '${tempDir.path}/mind_ops.jsonl';
    final log = await PersistentOperationLog.open(path);

    final sequence = await log.append(
      kind: MindOpKind.meetingIrExtracted,
      title: 'Standup minutes extracted',
      contextId: 'scribe',
      detail: 'm1;decisions=1;action_items=2;metrics=0',
    );

    expect(sequence, 1);

    final reopened = await PersistentOperationLog.open(path);
    expect(await reopened.count(), 1);
    final op = await reopened.bySequence(1);
    expect(op?.kind, MindOpKind.meetingIrExtracted);
    expect(op?.detail, contains('m1'));
  });

  test('lazy log shares opened file across calls', () async {
    final path = '${tempDir.path}/lazy.jsonl';
    final lazy = LazyPersistentOperationLog(
      opener: PersistentOperationLog.open(path),
    );

    await lazy.append(
      kind: MindOpKind.consent,
      title: 'Recording consent',
      contextId: 'scribe',
    );

    final reopened = await PersistentOperationLog.open(path);
    expect(await reopened.count(), 1);
  });
}
