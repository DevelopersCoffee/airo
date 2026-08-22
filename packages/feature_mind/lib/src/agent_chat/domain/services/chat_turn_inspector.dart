import 'package:core_ai/core_ai.dart';

import '../models/chat_response_metadata.dart';

const draftDietPlanPluginId = 'draft-diet-plan';

/// Chip label for the existing Response details / Turn inspector affordance.
String chatTurnInspectorSummary({
  ChatTurnTrace? turnTrace,
  ChatResponseMetadata? metadata,
}) {
  if (turnTrace != null && turnTrace.lifecycle == ChatTurnLifecycle.aborted) {
    final ms =
        turnTrace.duration?.inMilliseconds ?? metadata?.totalDurationMs ?? 0;
    return 'Aborted · ${formatChatTurnDuration(ms)}';
  }
  if (metadata != null) {
    final duration = formatChatTurnDuration(metadata.totalDurationMs);
    final toolCount = metadata.toolCount;
    if (toolCount != null && toolCount > 0) {
      return '$toolCount ${toolCount == 1 ? 'tool' : 'tools'} · $duration';
    }
    return '${metadata.title} · $duration';
  }
  if (turnTrace != null) {
    final ms = turnTrace.duration?.inMilliseconds ?? 0;
    return 'Turn inspector · ${formatChatTurnDuration(ms)}';
  }
  return 'Turn inspector';
}

String formatChatTurnDuration(int durationMs) {
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  return '${(durationMs / 1000).toStringAsFixed(1)}s';
}

String? parentRunIdFromMessages(Iterable<AgentChatTurnRef> messages) {
  for (final message in messages.toList().reversed) {
    if (message.isUser) continue;
    if (message.runId == null) continue;
    if (message.lifecycle == ChatTurnLifecycle.aborted) {
      return message.runId;
    }
    return null;
  }
  return null;
}

/// Minimal view of a bubble used to parent a continuation run.
class AgentChatTurnRef {
  const AgentChatTurnRef({required this.isUser, this.runId, this.lifecycle});

  final bool isUser;
  final String? runId;
  final ChatTurnLifecycle? lifecycle;
}

List<ChatTurnInertiaDelta> chatTurnInertiaDeltas({
  required String currentPrompt,
  required Iterable<String> priorUserPrompts,
  PromptInertiaGuard guard = PromptInertiaGuard.defaults,
}) {
  final current = guard.latestValues(currentPrompt);
  if (current.isEmpty) return const [];
  final deltas = <ChatTurnInertiaDelta>[];
  for (final prior in priorUserPrompts) {
    final previous = guard.latestValues(prior);
    for (final entry in current.entries) {
      final prev = previous[entry.key];
      if (prev != null && prev != entry.value) {
        deltas.add(
          ChatTurnInertiaDelta(
            kindId: entry.key,
            previousValue: prev,
            currentValue: entry.value,
          ),
        );
      }
    }
  }
  return deltas;
}

ChatTurnTraceBuilder startChatGenerateTurn({
  required String runId,
  required String runtimeId,
  required ChatTurnRouting routing,
  required String userPrompt,
  String? parentRunId,
  String? pluginId,
  bool gbnfAttached = false,
  String? prefixHash,
  Iterable<ChatTurnInertiaDelta> inertia = const [],
  DateTime? startedAt,
}) {
  var builder = ChatTurnTraceBuilder(
    runId: runId,
    parentRunId: parentRunId,
    startedAt: startedAt,
  ).runtime(id: runtimeId, routing: routing).prompt(summary: userPrompt);
  if (pluginId != null) {
    builder = builder.plugin(pluginId);
  }
  builder = builder.constraint(
    gbnfAttached: gbnfAttached,
    prefixHash: prefixHash,
  );
  for (final delta in inertia) {
    builder = builder.inertia(
      kindId: delta.kindId,
      previousValue: delta.previousValue,
      currentValue: delta.currentValue,
    );
  }
  return builder;
}
