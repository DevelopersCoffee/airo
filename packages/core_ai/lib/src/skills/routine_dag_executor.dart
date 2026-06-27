import 'package:meta/meta.dart';

import 'skill_permission_engine.dart';
import 'skill_schema.dart';

/// Routine node categories used by the deterministic DAG executor.
enum RoutineNodeType { prompt, skill, tool, response }

/// Lifecycle states for a routine run.
enum RoutineRunState { pending, running, paused, succeeded, failed, cancelled }

/// Lifecycle states for a single routine node.
enum RoutineNodeRunState {
  pending,
  running,
  paused,
  succeeded,
  failed,
  skipped,
}

/// Directed edge between two routine nodes.
@immutable
class RoutineEdge {
  const RoutineEdge({required this.from, required this.to});

  final String from;
  final String to;
}

/// Node definition for a routine DAG.
@immutable
class RoutineNode {
  const RoutineNode({
    required this.id,
    required this.type,
    this.isOptional = false,
    this.action,
  });

  final String id;
  final RoutineNodeType type;
  final bool isOptional;
  final SkillActionRequest? action;
}

/// Typed routine graph definition.
@immutable
class RoutineDag {
  const RoutineDag({
    required this.id,
    required this.nodes,
    this.edges = const [],
  });

  final String id;
  final List<RoutineNode> nodes;
  final List<RoutineEdge> edges;

  RoutineNode nodeById(String id) => nodes.singleWhere((node) => node.id == id);
}

/// Handler context with merged upstream node output.
@immutable
class RoutineNodeContext {
  const RoutineNodeContext({
    required this.run,
    required this.node,
    required this.input,
  });

  final RoutineRun run;
  final RoutineNode node;
  final Map<String, Object?> input;
}

typedef RoutineNodeCallback =
    Future<Map<String, Object?>> Function(RoutineNodeContext context);

/// Executable handler for a routine node.
class RoutineNodeHandler {
  const RoutineNodeHandler(this._callback);

  factory RoutineNodeHandler.sync(
    Map<String, Object?> Function(RoutineNodeContext context) callback,
  ) {
    return RoutineNodeHandler((context) async => callback(context));
  }

  final RoutineNodeCallback _callback;

  Future<Map<String, Object?>> call(RoutineNodeContext context) =>
      _callback(context);
}

/// Deterministic node failure with a stable code for persisted traces.
@immutable
class RoutineNodeException implements Exception {
  const RoutineNodeException(this.code, [this.message]);

  final String code;
  final String? message;

  @override
  String toString() => message == null ? code : '$code: $message';
}

/// Redacted node execution trace.
@immutable
class RoutineNodeTrace {
  const RoutineNodeTrace({
    required this.runId,
    required this.nodeId,
    required this.state,
    this.errorCode,
  });

  final String runId;
  final String nodeId;
  final RoutineNodeRunState state;
  final String? errorCode;

  Map<String, Object?> toJson() => {
    'run_id': runId,
    'node_id': nodeId,
    'state': state.name,
    if (errorCode != null) 'error_code': errorCode,
  };
}

/// Persistable routine run state.
@immutable
class RoutineRun {
  const RoutineRun({
    required this.id,
    required this.dag,
    required this.state,
    required this.nodeStates,
    required this.outputs,
    required this.traces,
    this.pendingConfirmationNodeId,
    this.approvedConfirmationNodeId,
    this.errorCode,
  });

  factory RoutineRun.pending({required RoutineDag dag, String? id}) {
    final runId = id ?? 'run-${dag.id}';
    return RoutineRun(
      id: runId,
      dag: dag,
      state: RoutineRunState.pending,
      nodeStates: {
        for (final node in dag.nodes) node.id: RoutineNodeRunState.pending,
      },
      outputs: const {},
      traces: const [],
    );
  }

  final String id;
  final RoutineDag dag;
  final RoutineRunState state;
  final Map<String, RoutineNodeRunState> nodeStates;
  final Map<String, Map<String, Object?>> outputs;
  final List<RoutineNodeTrace> traces;
  final String? pendingConfirmationNodeId;
  final String? approvedConfirmationNodeId;
  final String? errorCode;

  bool get isTerminal =>
      state == RoutineRunState.succeeded ||
      state == RoutineRunState.failed ||
      state == RoutineRunState.cancelled;

  RoutineRun approvePendingConfirmation() {
    final pendingNodeId = pendingConfirmationNodeId;
    if (state != RoutineRunState.paused || pendingNodeId == null) return this;
    return copyWith(
      state: RoutineRunState.pending,
      pendingConfirmationNodeId: _unsetString,
      approvedConfirmationNodeId: pendingNodeId,
    );
  }

  RoutineRun copyWith({
    String? id,
    RoutineDag? dag,
    RoutineRunState? state,
    Map<String, RoutineNodeRunState>? nodeStates,
    Map<String, Map<String, Object?>>? outputs,
    List<RoutineNodeTrace>? traces,
    Object? pendingConfirmationNodeId = _keep,
    Object? approvedConfirmationNodeId = _keep,
    Object? errorCode = _keep,
  }) {
    return RoutineRun(
      id: id ?? this.id,
      dag: dag ?? this.dag,
      state: state ?? this.state,
      nodeStates: nodeStates ?? this.nodeStates,
      outputs: outputs ?? this.outputs,
      traces: traces ?? this.traces,
      pendingConfirmationNodeId: pendingConfirmationNodeId == _keep
          ? this.pendingConfirmationNodeId
          : pendingConfirmationNodeId == _unsetString
          ? null
          : pendingConfirmationNodeId as String?,
      approvedConfirmationNodeId: approvedConfirmationNodeId == _keep
          ? this.approvedConfirmationNodeId
          : approvedConfirmationNodeId == _unsetString
          ? null
          : approvedConfirmationNodeId as String?,
      errorCode: errorCode == _keep
          ? this.errorCode
          : errorCode == _unsetString
          ? null
          : errorCode as String?,
    );
  }
}

const Object _keep = Object();
const Object _unsetString = Object();

/// Persistence boundary for routine run state and trace lookup.
abstract class RoutineRunStore {
  Future<void> saveRun(RoutineRun run);

  Future<RoutineRun?> readRun(String runId);

  Future<List<RoutineNodeTrace>> tracesForRun(String runId);
}

/// Deterministic in-memory store for tests and local framework consumers.
class RoutineRunMemoryStore implements RoutineRunStore {
  final Map<String, RoutineRun> _runsById = {};

  @override
  Future<void> saveRun(RoutineRun run) async {
    _runsById[run.id] = run;
  }

  @override
  Future<RoutineRun?> readRun(String runId) async => _runsById[runId];

  @override
  Future<List<RoutineNodeTrace>> tracesForRun(String runId) async {
    return List<RoutineNodeTrace>.unmodifiable(
      _runsById[runId]?.traces ?? const [],
    );
  }
}

/// Pure deterministic executor for typed routine DAGs.
class RoutineDagExecutor {
  const RoutineDagExecutor({
    required this.handlers,
    this.permissionEngine = const SkillPermissionEngine(),
    this.store,
  });

  final Map<String, RoutineNodeHandler> handlers;
  final SkillPermissionEngine permissionEngine;
  final RoutineRunStore? store;

  Future<RoutineRun> run(RoutineDag dag) =>
      resume(RoutineRun.pending(dag: dag));

  Future<RoutineRun> resume(RoutineRun initialRun) async {
    var run = initialRun.copyWith(state: RoutineRunState.running);
    for (final node in _executionOrder(run.dag)) {
      final state = run.nodeStates[node.id] ?? RoutineNodeRunState.pending;
      if (state == RoutineNodeRunState.succeeded ||
          state == RoutineNodeRunState.failed) {
        continue;
      }

      final permissionDecision = _permissionDecisionFor(node);
      if (permissionDecision?.tier == SkillTrustTier.blocked) {
        return _saveAndReturn(_fail(run, node.id, 'permission_blocked'));
      }
      if (permissionDecision?.tier == SkillTrustTier.draftOnly) {
        return _saveAndReturn(_fail(run, node.id, 'draft_only'));
      }
      if (permissionDecision?.tier == SkillTrustTier.confirmationRequired &&
          run.approvedConfirmationNodeId != node.id) {
        return _saveAndReturn(_pause(run, node.id));
      }

      run = await _executeNode(run, node);
      if (run.state == RoutineRunState.failed) return _saveAndReturn(run);
    }

    return _saveAndReturn(
      run.copyWith(
        state: RoutineRunState.succeeded,
        approvedConfirmationNodeId: _unsetString,
      ),
    );
  }

  Future<RoutineRun> cancel(RoutineRun run, {required String reason}) async {
    return _saveAndReturn(
      run.copyWith(
        state: RoutineRunState.cancelled,
        errorCode: reason,
        traces: [
          ...run.traces,
          RoutineNodeTrace(
            runId: run.id,
            nodeId: run.pendingConfirmationNodeId ?? run.dag.nodes.first.id,
            state: RoutineNodeRunState.skipped,
            errorCode: reason,
          ),
        ],
      ),
    );
  }

  Future<RoutineRun> _saveAndReturn(RoutineRun run) async {
    await store?.saveRun(run);
    return run;
  }

  SkillPermissionDecision? _permissionDecisionFor(RoutineNode node) {
    final action = node.action;
    return action == null ? null : permissionEngine.resolve(action);
  }

  Future<RoutineRun> _executeNode(RoutineRun run, RoutineNode node) async {
    final handler = handlers[node.id];
    if (handler == null) return _fail(run, node.id, 'missing_handler');

    final runningStates = Map<String, RoutineNodeRunState>.of(run.nodeStates)
      ..[node.id] = RoutineNodeRunState.running;
    run = run.copyWith(nodeStates: runningStates);

    try {
      final output = await handler(
        RoutineNodeContext(run: run, node: node, input: _inputFor(run, node)),
      );
      final nextStates = Map<String, RoutineNodeRunState>.of(run.nodeStates)
        ..[node.id] = RoutineNodeRunState.succeeded;
      final nextOutputs = Map<String, Map<String, Object?>>.of(run.outputs)
        ..[node.id] = Map<String, Object?>.unmodifiable(output);
      return run.copyWith(
        nodeStates: nextStates,
        outputs: nextOutputs,
        traces: [
          ...run.traces,
          RoutineNodeTrace(
            runId: run.id,
            nodeId: node.id,
            state: RoutineNodeRunState.succeeded,
          ),
        ],
      );
    } on RoutineNodeException catch (error) {
      if (node.isOptional) {
        final failedStates = Map<String, RoutineNodeRunState>.of(run.nodeStates)
          ..[node.id] = RoutineNodeRunState.failed;
        return run.copyWith(
          nodeStates: failedStates,
          traces: [
            ...run.traces,
            RoutineNodeTrace(
              runId: run.id,
              nodeId: node.id,
              state: RoutineNodeRunState.failed,
              errorCode: error.code,
            ),
          ],
        );
      }
      return _fail(run, node.id, error.code);
    } catch (_) {
      return _fail(run, node.id, 'node_failed');
    }
  }

  RoutineRun _pause(RoutineRun run, String nodeId) {
    final pausedStates = Map<String, RoutineNodeRunState>.of(run.nodeStates)
      ..[nodeId] = RoutineNodeRunState.paused;
    return run.copyWith(
      state: RoutineRunState.paused,
      nodeStates: pausedStates,
      pendingConfirmationNodeId: nodeId,
      traces: [
        ...run.traces,
        RoutineNodeTrace(
          runId: run.id,
          nodeId: nodeId,
          state: RoutineNodeRunState.paused,
        ),
      ],
    );
  }

  RoutineRun _fail(RoutineRun run, String nodeId, String errorCode) {
    final failedStates = Map<String, RoutineNodeRunState>.of(run.nodeStates)
      ..[nodeId] = RoutineNodeRunState.failed;
    return run.copyWith(
      state: RoutineRunState.failed,
      nodeStates: failedStates,
      errorCode: errorCode,
      traces: [
        ...run.traces,
        RoutineNodeTrace(
          runId: run.id,
          nodeId: nodeId,
          state: RoutineNodeRunState.failed,
          errorCode: errorCode,
        ),
      ],
    );
  }

  Map<String, Object?> _inputFor(RoutineRun run, RoutineNode node) {
    final input = <String, Object?>{};
    for (final edge in run.dag.edges.where((edge) => edge.to == node.id)) {
      input.addAll(run.outputs[edge.from] ?? const {});
    }
    return input;
  }

  List<RoutineNode> _executionOrder(RoutineDag dag) {
    final sorted = <RoutineNode>[];
    final remaining = dag.nodes.map((node) => node.id).toSet();
    while (remaining.isNotEmpty) {
      final ready = dag.nodes.where((node) {
        if (!remaining.contains(node.id)) return false;
        return dag.edges
            .where((edge) => edge.to == node.id)
            .every((edge) => !remaining.contains(edge.from));
      }).toList();
      if (ready.isEmpty) {
        throw const RoutineNodeException('dag_cycle');
      }
      for (final node in ready) {
        remaining.remove(node.id);
        sorted.add(node);
      }
    }
    return sorted;
  }
}
