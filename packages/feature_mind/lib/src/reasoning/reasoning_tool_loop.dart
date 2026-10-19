import 'dart:convert';

import 'package:core_ai/core_ai.dart';

import '../agent_chat/domain/services/agent_connector_registry.dart';
import 'google_mobile_action_tools.dart';
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

const List<LiteRtLmToolSpec> kLiteRtLookupToolSpecs = [
  LiteRtLmToolSpec(
    name: 'get_current_date_time',
    description: 'Current local date, time, weekday, and timezone.',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  ),
  LiteRtLmToolSpec(
    name: 'read_calendar_events',
    description: 'Events on a local calendar day. date is YYYY-MM-DD.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {'type': 'string', 'description': 'Start date, YYYY-MM-DD.'},
        'end_date': {
          'type': 'string',
          'description': 'Optional inclusive end date, YYYY-MM-DD.',
        },
      },
      'required': ['date'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'calendar_permission_status',
    description: 'Whether calendar read access is granted. No arguments.',
    parameters: {'type': 'object', 'properties': <String, Object?>{}},
  ),
  LiteRtLmToolSpec(
    name: 'query_lifetrack_status',
    description: 'Look up a local LifeTrack goal from a short query.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'What the user wants to know about a LifeTrack.',
        },
      },
      'required': ['query'],
    },
  ),
];

List<LiteRtLmToolSpec> liteRtLookupToolSpecs(AgentConnectorRegistry registry) {
  return [
    for (final spec in kLiteRtLookupToolSpecs)
      if (registry.getConnector(spec.name) != null) spec,
  ];
}

const kAiroActionsModelId = 'airo-actions-270m-litertlm';
const kMobileActionsModelId = kGoogleMobileActionsModelId;

/// Google's seven mobile action tools run when `mobile-actions-270m-litertlm` is loaded.
const kLiteRtGoogleMobileActionToolSpecs = kGoogleMobileActionToolSpecs;

/// Tools supported by Airo's on-device action model (`airo-actions-270m-litertlm`).
const List<LiteRtLmToolSpec> kLiteRtAiroActionToolSpecs = [
  LiteRtLmToolSpec(
    name: 'get_current_date_time',
    description:
        'Current local date, time, weekday, and timezone. No arguments.',
    parameters: {
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
    },
  ),
  LiteRtLmToolSpec(
    name: 'read_calendar_events',
    description:
        'Read calendar events for a date or date range. date and end_date are YYYY-MM-DD. date is required.',
    parameters: {
      'type': 'object',
      'properties': {
        'date': {
          'type': 'string',
          'description': 'Start date in YYYY-MM-DD format',
        },
        'end_date': {
          'type': 'string',
          'description': 'Optional end date in YYYY-MM-DD format',
        },
      },
      'required': ['date'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'calendar_permission_status',
    description: 'Whether calendar read access is granted. No arguments.',
    parameters: {
      'type': 'object',
      'properties': <String, Object?>{},
      'required': <String>[],
    },
  ),
  LiteRtLmToolSpec(
    name: 'query_lifetrack_status',
    description:
        'query is a short question about a local LifeTrack goal. Required.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': 'Short question about a local LifeTrack goal',
        },
      },
      'required': ['query'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'open_route',
    description:
        'Open an Airo app route. target is one of: money, budget, expenses, split, assistant, models, music, tv, games, chess, quest.',
    parameters: {
      'type': 'object',
      'properties': {
        'target': {
          'type': 'string',
          'enum': [
            'money',
            'budget',
            'expenses',
            'split',
            'assistant',
            'models',
            'music',
            'tv',
            'games',
            'chess',
            'quest',
          ],
          'description': 'Target screen or route identifier',
        },
      },
      'required': ['target'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'schedule_notification',
    description:
        'Schedule a reminder notification. hour is 0-23. minute is 0-59. date is YYYY-MM-DD when for one day. repeat_daily is true only when asked for every day.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string', 'description': 'Title of the reminder'},
        'message': {
          'type': 'string',
          'description': 'Message or details of the reminder',
        },
        'hour': {
          'type': 'integer',
          'description': 'Hour in 24-hour format (0-23)',
        },
        'minute': {'type': 'integer', 'description': 'Minute (0-59)'},
        'date': {
          'type': 'string',
          'description': 'Optional date in YYYY-MM-DD format',
        },
        'repeat_daily': {
          'type': 'boolean',
          'description': 'Whether the reminder repeats daily',
        },
      },
      'required': ['title', 'message', 'hour', 'minute'],
    },
  ),
  LiteRtLmToolSpec(
    name: 'record_lifetrack_facts',
    description:
        "The user is stating a fact to store on a LifeTrack, not asking for status. query is the fact in the user's words.",
    parameters: {
      'type': 'object',
      'properties': {
        'query': {
          'type': 'string',
          'description': "The fact in the user's words",
        },
      },
      'required': ['query'],
    },
  ),
];

/// Returns the appropriate LiteRT tool specifications for the given [modelId].
///
/// - When [modelId] is `airo-actions-270m-litertlm`, offers only the 7 Airo action tools.
/// - When [modelId] is `mobile-actions-270m-litertlm`, offers Google's 7 tools.
/// - When [supportsFunctionCalling] is true for any other package, offers the 4 lookup tools.
/// - Otherwise returns an empty list.
List<LiteRtLmToolSpec> liteRtToolSpecsForModel({
  required String? modelId,
  required AgentConnectorRegistry registry,
  bool supportsFunctionCalling = false,
}) {
  if (modelId == kAiroActionsModelId) {
    return [
      for (final spec in kLiteRtAiroActionToolSpecs)
        if (registry.getConnector(spec.name) != null) spec,
    ];
  }
  if (modelId == kGoogleMobileActionsModelId ||
      modelId == kMobileActionsModelId) {
    return kGoogleMobileActionToolSpecs;
  }
  if (supportsFunctionCalling) {
    return liteRtLookupToolSpecs(registry);
  }
  return const [];
}

/// Returns the appropriate LiteRT tool specifications for the given [package].
List<LiteRtLmToolSpec> liteRtToolSpecsForPackage(
  OfflineModelInfo? package,
  AgentConnectorRegistry registry,
) {
  if (package == null) return const [];
  return liteRtToolSpecsForModel(
    modelId: package.id,
    registry: registry,
    supportsFunctionCalling: package.supportsFunctionCalling,
  );
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

Future<String> executeLiteRtLookupTool({
  required AgentConnectorRegistry registry,
  required String name,
  required Map<String, Object?> arguments,
}) {
  return executeReasoningTool(
    registry: registry,
    name: name,
    argumentsJson: jsonEncode(arguments),
  );
}

/// Alias for [executeLiteRtLookupTool] supporting all LiteRT action and lookup tools.
Future<String> executeLiteRtTool({
  required AgentConnectorRegistry registry,
  required String name,
  required Map<String, Object?> arguments,
}) => executeLiteRtLookupTool(
  registry: registry,
  name: name,
  arguments: arguments,
);

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
