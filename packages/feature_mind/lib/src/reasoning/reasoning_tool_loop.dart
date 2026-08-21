import 'dart:convert';

import 'package:core_ai/core_ai.dart';

import '../agent_chat/domain/services/agent_connector_registry.dart';
import 'reasoning_models.dart';

/// Same cap as Rust [`MAX_TOOL_ITERATIONS`]. Counts executed tools.
const kMaxReasoningToolIterations = 5;

/// Lookup-only connectors the reasoning engine may name. Side-effecting
/// verbs (create event, open route, notify) stay on the skill orchestrator.
const kReasoningLookupToolNames = {
  'get_current_date_time',
  'read_calendar_events',
  'calendar_permission_status',
  'query_lifetrack_status',
};

const kReasoningToolBudgetMessage =
    'This request needed too many steps. Try a simpler question.';

List<String> reasoningLookupToolNames(AgentConnectorRegistry registry) {
  return [
    for (final name in kReasoningLookupToolNames)
      if (registry.getConnector(name) != null) name,
  ];
}

Map<String, dynamic> decodeToolArguments(String raw) {
  if (raw.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
  } on Object {
    return const {};
  }
  return const {};
}

Future<String> executeReasoningTool({
  required AgentConnectorRegistry registry,
  required String name,
  required String argumentsJson,
}) async {
  final arguments = decodeToolArguments(argumentsJson);
  final result = await registry.execute(name, arguments);
  if (result.isError) {
    return result.message ?? 'Tool failed.';
  }
  return jsonEncode(result.data);
}

/// Host-side loop when the Rust engine has no native tool executor. Calendar and
/// similar verbs live in Dart; Rust still parsed the envelope.
///
/// Intermediate `Completed` events that only request tools are not yielded.
Stream<MindReasoningEvent> runReasoningToolLoop({
  required MindReasoningRequest request,
  required Stream<MindReasoningEvent> Function(MindReasoningRequest request)
  reason,
  required Future<String> Function(String name, String argumentsJson)
  executeTool,
  int maxIterations = kMaxReasoningToolIterations,
}) async* {
  var current = request;
  final executed = <MindReasoningToolCall>[];

  for (var round = 0; round <= maxIterations; round++) {
    MindReasoningCompleted? completed;
    await for (final event in reason(current)) {
      if (event is MindReasoningCompleted) {
        completed = event;
        continue;
      }
      yield event;
      if (event is MindReasoningError || event is MindReasoningCancelled) {
        return;
      }
    }
    if (completed == null) return;
    if (completed.toolCalls.isEmpty) {
      yield MindReasoningCompleted(
        answer: completed.answer,
        reasoningSummary: completed.reasoningSummary,
        level: completed.level,
        confidence: completed.confidence,
        toolCalls: [...executed, ...completed.toolCalls],
      );
      return;
    }

    if (executed.length >= maxIterations) {
      yield const MindReasoningError(kReasoningToolBudgetMessage);
      return;
    }

    final remaining = maxIterations - executed.length;
    final take = completed.level == MindReasoningLevel.none
        ? remaining.clamp(0, 1)
        : remaining;
    final batch = completed.toolCalls.take(take).toList(growable: false);
    if (batch.isEmpty) {
      yield const MindReasoningError(kReasoningToolBudgetMessage);
      return;
    }

    final nextResults = [...current.toolResults];
    for (final call in batch) {
      if (executed.length >= maxIterations) {
        yield const MindReasoningError(kReasoningToolBudgetMessage);
        return;
      }
      yield MindReasoningToolStarted(call.name);
      final output = await executeTool(call.name, call.argumentsJson);
      yield MindReasoningToolCompleted(call.name);
      executed.add(call);
      nextResults.add(
        MindReasoningContextItem(
          source: call.name,
          text: ContextCompiler.wrapAsData(output),
        ),
      );
      if (completed.level == MindReasoningLevel.none) {
        yield MindReasoningCompleted(
          answer: output,
          reasoningSummary: 'Used ${call.name}.',
          level: MindReasoningLevel.none,
          confidence: completed.confidence,
          toolCalls: List<MindReasoningToolCall>.from(executed),
        );
        return;
      }
    }
    current = current.copyWith(toolResults: nextResults);
  }

  yield const MindReasoningError(kReasoningToolBudgetMessage);
}
