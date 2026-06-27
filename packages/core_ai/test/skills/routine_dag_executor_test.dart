import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RoutineDagExecutor', () {
    test(
      'executes a linear routine in dependency order and records traces',
      () async {
        final calls = <String>[];
        final executor = RoutineDagExecutor(
          handlers: {
            'prompt': RoutineNodeHandler.sync((context) {
              calls.add('prompt');
              return {'prompt': 'plan my morning'};
            }),
            'skill': RoutineNodeHandler.sync((context) {
              calls.add('skill:${context.input['prompt']}');
              return {'tool': 'calendar.events.list'};
            }),
            'tool': RoutineNodeHandler.sync((context) {
              calls.add('tool:${context.input['tool']}');
              return {'response': 'done'};
            }),
          },
        );

        final run = await executor.run(
          RoutineDag(
            id: 'linear-routine',
            nodes: [
              const RoutineNode(id: 'prompt', type: RoutineNodeType.prompt),
              const RoutineNode(id: 'skill', type: RoutineNodeType.skill),
              const RoutineNode(id: 'tool', type: RoutineNodeType.tool),
            ],
            edges: const [
              RoutineEdge(from: 'prompt', to: 'skill'),
              RoutineEdge(from: 'skill', to: 'tool'),
            ],
          ),
        );

        expect(run.state, RoutineRunState.succeeded);
        expect(calls, [
          'prompt',
          'skill:plan my morning',
          'tool:calendar.events.list',
        ]);
        expect(run.nodeStates['tool'], RoutineNodeRunState.succeeded);
        expect(run.outputs['tool']?['response'], 'done');
        expect(run.traces.map((trace) => trace.nodeId), [
          'prompt',
          'skill',
          'tool',
        ]);
        expect(run.traces.every((trace) => trace.runId == run.id), isTrue);
      },
    );

    test(
      'continues past failed optional nodes and records the error code',
      () async {
        final executor = RoutineDagExecutor(
          handlers: {
            'required': RoutineNodeHandler.sync((context) => {'ok': true}),
            'optional': RoutineNodeHandler.sync((context) {
              throw const RoutineNodeException('optional_unavailable');
            }),
            'after': RoutineNodeHandler.sync((context) => {'after': true}),
          },
        );

        final run = await executor.run(
          RoutineDag(
            id: 'optional-failure',
            nodes: [
              const RoutineNode(id: 'required', type: RoutineNodeType.skill),
              const RoutineNode(
                id: 'optional',
                type: RoutineNodeType.tool,
                isOptional: true,
              ),
              const RoutineNode(id: 'after', type: RoutineNodeType.response),
            ],
            edges: const [
              RoutineEdge(from: 'required', to: 'optional'),
              RoutineEdge(from: 'optional', to: 'after'),
            ],
          ),
        );

        expect(run.state, RoutineRunState.succeeded);
        expect(run.nodeStates['optional'], RoutineNodeRunState.failed);
        expect(run.nodeStates['after'], RoutineNodeRunState.succeeded);
        expect(
          run.traces
              .singleWhere((trace) => trace.nodeId == 'optional')
              .errorCode,
          'optional_unavailable',
        );
      },
    );

    test(
      'pauses before confirmation-required tool side effects and resumes safely',
      () async {
        final sideEffects = <String>[];
        final executor = RoutineDagExecutor(
          permissionEngine: const SkillPermissionEngine(),
          handlers: {
            'reminder': RoutineNodeHandler.sync((context) {
              sideEffects.add('created-reminder');
              return {'created': true};
            }),
          },
        );
        final dag = RoutineDag(
          id: 'confirmation-routine',
          nodes: [
            const RoutineNode(
              id: 'reminder',
              type: RoutineNodeType.tool,
              action: SkillActionRequest(
                toolId: 'reminders.create',
                domain: SkillActionDomain.reminders,
                operation: SkillActionOperation.create,
                source: SkillActionSource.builtIn,
              ),
            ),
          ],
        );

        final paused = await executor.run(dag);

        expect(paused.state, RoutineRunState.paused);
        expect(paused.nodeStates['reminder'], RoutineNodeRunState.paused);
        expect(sideEffects, isEmpty);
        expect(paused.pendingConfirmationNodeId, 'reminder');

        final resumed = await executor.resume(
          paused.approvePendingConfirmation(),
        );

        expect(resumed.state, RoutineRunState.succeeded);
        expect(sideEffects, ['created-reminder']);
        expect(resumed.nodeStates['reminder'], RoutineNodeRunState.succeeded);
      },
    );

    test(
      'cancels a pending routine and persists terminal cancellation state',
      () async {
        final executor = RoutineDagExecutor(
          handlers: {
            'first': RoutineNodeHandler.sync((context) => {'first': true}),
            'second': RoutineNodeHandler.sync((context) => {'second': true}),
          },
        );

        final run = RoutineRun.pending(
          dag: RoutineDag(
            id: 'cancel-routine',
            nodes: [
              const RoutineNode(id: 'first', type: RoutineNodeType.skill),
              const RoutineNode(id: 'second', type: RoutineNodeType.tool),
            ],
            edges: const [RoutineEdge(from: 'first', to: 'second')],
          ),
        );

        final cancelled = await executor.cancel(run, reason: 'user_cancelled');

        expect(cancelled.state, RoutineRunState.cancelled);
        expect(cancelled.errorCode, 'user_cancelled');
        expect(cancelled.isTerminal, isTrue);
        expect(cancelled.traces.single.errorCode, 'user_cancelled');
      },
    );
    test(
      'stores runs for restart-safe resume and trace lookup by run id',
      () async {
        final store = RoutineRunMemoryStore();
        final sideEffects = <String>[];
        final dag = RoutineDag(
          id: 'persisted-confirmation-routine',
          nodes: [
            const RoutineNode(
              id: 'reminder',
              type: RoutineNodeType.tool,
              action: SkillActionRequest(
                toolId: 'reminders.create',
                domain: SkillActionDomain.reminders,
                operation: SkillActionOperation.create,
                source: SkillActionSource.builtIn,
              ),
            ),
          ],
        );

        final firstExecutor = RoutineDagExecutor(
          store: store,
          handlers: {
            'reminder': RoutineNodeHandler.sync((context) {
              sideEffects.add('first-executor');
              return {'created': true};
            }),
          },
        );

        final paused = await firstExecutor.run(dag);
        final restored = await store.readRun(paused.id);

        expect(restored?.state, RoutineRunState.paused);
        expect(sideEffects, isEmpty);
        expect(await store.tracesForRun(paused.id), hasLength(1));

        final secondExecutor = RoutineDagExecutor(
          store: store,
          handlers: {
            'reminder': RoutineNodeHandler.sync((context) {
              sideEffects.add('second-executor');
              return {'created': true};
            }),
          },
        );

        final resumed = await secondExecutor.resume(
          restored!.approvePendingConfirmation(),
        );

        expect(resumed.state, RoutineRunState.succeeded);
        expect(sideEffects, ['second-executor']);
        expect(await store.readRun(resumed.id), resumed);
        expect(
          (await store.tracesForRun(resumed.id)).map((trace) => trace.state),
          [RoutineNodeRunState.paused, RoutineNodeRunState.succeeded],
        );
      },
    );
  });
}
