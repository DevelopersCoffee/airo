import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiTrajectoryTrace', () {
    test('emits a deterministic redacted read-only tool trajectory', () {
      final trace = AiTrajectoryTraceBuilder(runId: 'run-001')
          .promptRef(
            ref: 'local://prompts/run-001',
            summary:
                'Check my calendar; secret token sk-live-abc and heart rate 160',
          )
          .selectedSkill('read-calendar-events')
          .toolCall('read_calendar_events')
          .parametersRef(
            ref: 'local://params/run-001/read-calendar',
            summary: 'date 2026-06-20 account 4242 4242 4242 4242',
          )
          .resultRef(
            ref: 'local://results/run-001/read-calendar',
            summary: '2 meetings with blood pressure details',
          )
          .finalAnswerRef(
            ref: 'local://answers/run-001',
            summary: 'Here is your schedule with memory: childhood address',
          )
          .build();

      expect(trace.nodes.map((node) => node.kind), [
        AiTrajectoryNodeKind.promptRef,
        AiTrajectoryNodeKind.selectedSkill,
        AiTrajectoryNodeKind.toolCall,
        AiTrajectoryNodeKind.parametersRef,
        AiTrajectoryNodeKind.resultRef,
        AiTrajectoryNodeKind.finalAnswerRef,
      ]);
      expect(trace.nodes.map((node) => node.sequence), [0, 1, 2, 3, 4, 5]);
      expect(trace.nodes[0].ref, 'local://prompts/run-001');
      expect(trace.nodes[3].ref, 'local://params/run-001/read-calendar');
      expect(trace.toJson()['schema_version'], 1);

      final encoded = trace.toJson().toString();
      expect(encoded, isNot(contains('sk-live-abc')));
      expect(encoded, isNot(contains('4242 4242')));
      expect(encoded, isNot(contains('heart rate 160')));
      expect(encoded, isNot(contains('blood pressure')));
      expect(encoded, isNot(contains('childhood address')));
      expect(encoded, contains('[redacted:secret]'));
      expect(encoded, contains('[redacted:finance]'));
      expect(encoded, contains('[redacted:health]'));
      expect(encoded, contains('[redacted:memory]'));
    });

    test('records confirmation-required tool pauses before side effects', () {
      final trace = AiTrajectoryTraceBuilder(runId: 'run-confirm')
          .promptRef(ref: 'local://prompts/run-confirm', summary: 'remind me')
          .selectedSkill('schedule-notification')
          .toolCall('schedule_notification')
          .parametersRef(
            ref: 'local://params/run-confirm/schedule',
            summary: 'medicine Minoxidil at 8am',
          )
          .confirmationRequired(reason: 'requires_user_confirmation')
          .build();

      expect(trace.nodes.last.kind, AiTrajectoryNodeKind.confirmation);
      expect(trace.nodes.last.status, AiTrajectoryNodeStatus.pending);
      expect(trace.nodes.last.errorCode, isNull);
      expect(trace.toJson().toString(), isNot(contains('Minoxidil')));
    });

    test('records failed tool traces with sanitized errors only', () {
      final trace = AiTrajectoryTraceBuilder(runId: 'run-error')
          .promptRef(ref: 'local://prompts/run-error', summary: 'read memory')
          .selectedSkill('memory-search')
          .toolCall('search_memory')
          .parametersRef(
            ref: 'local://params/run-error/memory',
            summary: 'find childhood address and password hunter2',
          )
          .error(code: 'tool_failed', summary: 'Exception: password hunter2')
          .build();

      expect(trace.nodes.last.kind, AiTrajectoryNodeKind.error);
      expect(trace.nodes.last.status, AiTrajectoryNodeStatus.failed);
      expect(trace.nodes.last.errorCode, 'tool_failed');
      expect(trace.toJson().toString(), isNot(contains('hunter2')));
      expect(trace.toJson().toString(), contains('[redacted:secret]'));
    });

    test('supports routine nodes in the base schema', () {
      final trace = AiTrajectoryTraceBuilder(runId: 'routine-run')
          .routine('morning-routine')
          .promptRef(
            ref: 'local://prompts/routine-run',
            summary: 'start routine',
          )
          .finalAnswerRef(
            ref: 'local://answers/routine-run',
            summary: 'routine completed',
          )
          .build();

      expect(trace.nodes.first.kind, AiTrajectoryNodeKind.routine);
      expect(trace.nodes.first.label, 'morning-routine');
    });
  });
}
