import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatTurnTrace', () {
    test('aborts a diet generate without claiming stop', () {
      final started = DateTime.utc(2026, 8, 21, 14, 46);
      final trace =
          ChatTurnTraceBuilder(runId: 'run-diet-1', startedAt: started)
              .runtime(
                id: 'offline-gemma-2b-it-q4',
                routing: ChatTurnRouting.local,
              )
              .plugin('draft-diet-plan')
              .constraint(gbnfAttached: true, prefixHash: 'abc')
              .prompt(summary: 'Make me a 7 day diet plan')
              .markFirstToken()
              .abort(
                reason: ChatTurnStopReason.processKilled,
                endedAt: started.add(const Duration(seconds: 2)),
              )
              .build();

      expect(ChatTurnTrace.schemaVersion, 1);
      expect(trace.runId, 'run-diet-1');
      expect(trace.parentRunId, isNull);
      expect(trace.lifecycle, ChatTurnLifecycle.aborted);
      expect(trace.stopReason, ChatTurnStopReason.processKilled);
      expect(trace.pluginId, 'draft-diet-plan');
      expect(trace.skillId, isNull);
      expect(trace.constraint.gbnfAttached, isTrue);
      expect(trace.trajectory.nodes, isNotEmpty);
      expect(trace.trajectory.nodes.first.kind, AiTrajectoryNodeKind.promptRef);
      expect(
        trace.trajectory.nodes.any(
          (node) => node.kind == AiTrajectoryNodeKind.selectedSkill,
        ),
        isFalse,
      );
      expect(trace.toJson()['lifecycle'], 'aborted');
      expect(trace.toJson()['stop_reason'], 'process_killed');
    });

    test('follow-up completion keeps a new run id and parent', () {
      final trace =
          ChatTurnTraceBuilder(runId: 'run-diet-2', parentRunId: 'run-diet-1')
              .runtime(
                id: 'offline-gemma-2b-it-q4',
                routing: ChatTurnRouting.local,
              )
              .plugin('draft-diet-plan')
              .prompt(summary: 'i cant see the full response')
              .markFirstToken()
              .finish(reason: ChatTurnStopReason.eos)
              .build();

      expect(trace.runId, 'run-diet-2');
      expect(trace.parentRunId, 'run-diet-1');
      expect(trace.lifecycle, ChatTurnLifecycle.finished);
      expect(trace.stopReason, ChatTurnStopReason.eos);
      expect(trace.pluginId, 'draft-diet-plan');
    });

    test('records day-count inertia and redacts secrets in summaries', () {
      final trace = ChatTurnTraceBuilder(runId: 'run-diet-3')
          .runtime(id: 'offline-qwen', routing: ChatTurnRouting.local)
          .plugin('draft-diet-plan')
          .inertia(kindId: 'day_count', previousValue: 7, currentValue: 3)
          .constraint(gbnfAttached: true)
          .prompt(
            summary: 'for 3 days; secret token sk-live-abc and heart rate 160',
          )
          .finish()
          .build();

      expect(trace.inertia.single.kindId, 'day_count');
      expect(trace.inertia.single.previousValue, 7);
      expect(trace.inertia.single.currentValue, 3);
      expect(
        trace.trajectory.nodes.first.summary,
        contains('[redacted:secret]'),
      );
      expect(
        trace.trajectory.nodes.first.summary,
        contains('[redacted:health]'),
      );
      expect(trace.trajectory.nodes.first.summary, isNot(contains('sk-live')));
    });

    test('round-trips JSON including parent run and inertia', () {
      final original =
          ChatTurnTraceBuilder(
                runId: 'run-4',
                parentRunId: 'run-3',
                startedAt: DateTime.utc(2026, 8, 21, 15),
              )
              .runtime(id: 'offline-qwen', routing: ChatTurnRouting.local)
              .plugin('draft-diet-plan')
              .inertia(kindId: 'day_count', previousValue: 7, currentValue: 3)
              .constraint(gbnfAttached: false, prefixHash: 'pre')
              .stats(prefillMs: 12, generatedTokens: 40, maxOutputTokens: 2048)
              .prompt(summary: 'for 3 days')
              .finish(reason: ChatTurnStopReason.eos)
              .build();

      final restored = ChatTurnTrace.fromJson(original.toJson());
      expect(restored.runId, original.runId);
      expect(restored.parentRunId, 'run-3');
      expect(restored.lifecycle, ChatTurnLifecycle.finished);
      expect(restored.inertia.single.currentValue, 3);
      expect(restored.constraint.gbnfAttached, isFalse);
      expect(restored.stats.generatedTokens, 40);
      expect(restored.trajectory.nodes, hasLength(1));
    });
  });
}
