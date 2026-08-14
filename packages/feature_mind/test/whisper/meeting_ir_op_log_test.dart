import 'package:feature_mind/src/runtime/mind_runtime.dart' show MindPortUnavailable;
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime/ports/operation_log_port.dart';
import 'package:feature_mind/src/whisper/meeting_ir_op_log.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingLog implements OperationLogPort {
  final List<MindOp> appended = [];

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    final sequence = appended.length + 1;
    appended.add(
      MindOp(
        sequence: sequence,
        kind: kind,
        title: title,
        contextId: contextId,
        deviceName: 'Test device',
        signature: SignatureState.verified,
        recordedAtMs: 1000 + sequence,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<int> count() async => appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      appended.reversed.skip(offset).take(limit).toList();

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      appended.where((op) => op.sequence == sequence).firstOrNull;

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    yield 1.0;
  }
}

class _UnavailableLog implements OperationLogPort {
  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) => throw const MindPortUnavailable('operationLog', 'not implemented yet');

  @override
  Future<int> count() =>
      throw const MindPortUnavailable('operationLog', 'not implemented yet');

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) =>
      throw const MindPortUnavailable('operationLog', 'not implemented yet');

  @override
  Future<MindOp?> bySequence(int sequence) =>
      throw const MindPortUnavailable('operationLog', 'not implemented yet');

  @override
  Future<SignatureState> verify(int sequence) =>
      throw const MindPortUnavailable('operationLog', 'not implemented yet');

  @override
  Stream<double> replayFrom(int sequence) => Stream.error(
    const MindPortUnavailable('operationLog', 'not implemented yet'),
  );
}

void main() {
  group('appendMeetingIrExtractedOp', () {
    test('appends a meetingIrExtracted op with the expected shape', () async {
      final log = _RecordingLog();

      final sequence = await appendMeetingIrExtractedOp(
        log: log,
        meetingId: 'm1700000000',
        meetingTitle: 'Platform standup',
        contextId: 'ctx-1',
        decisionCount: 2,
        actionItemCount: 3,
        metricCount: 1,
      );

      expect(sequence, 1);
      expect(log.appended, hasLength(1));
      final op = log.appended.single;
      expect(op.kind, MindOpKind.meetingIrExtracted);
      expect(op.title, 'Platform standup minutes extracted');
      expect(op.contextId, 'ctx-1');
      expect(
        op.detail,
        'm1700000000;decisions=2;action_items=3;metrics=1',
      );
    });

    test(
      'degrades gracefully to null when the operation log is unavailable',
      () async {
        final sequence = await appendMeetingIrExtractedOp(
          log: _UnavailableLog(),
          meetingId: 'm1',
          meetingTitle: 'Standup',
          contextId: 'ctx-1',
          decisionCount: 0,
          actionItemCount: 0,
          metricCount: 0,
        );

        expect(sequence, isNull);
      },
    );
  });
}
