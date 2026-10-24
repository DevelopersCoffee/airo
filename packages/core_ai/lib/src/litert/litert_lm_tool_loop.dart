import 'dart:convert';

import 'litert_lm_runtime_adapter.dart';

const kLiteRtToolBudgetMessage =
    'This request needed too many steps. Try a simpler question.';

final _liteRtTextToolCall = RegExp(
  r'<([A-Za-z_][\w]*)>(?:\{([^}]*)\})?</\1>',
);

/// Reads `<tool_name>{arg:value,arg:value}</tool_name>` calls from reply text.
///
/// The Airo Actions model emits this text instead of a native LiteRT tool
/// call. An empty `{}` body, or a tag with no braces, means no arguments.
List<LiteRtLmToolCall> liteRtTextToolCalls(String text) {
  final calls = <LiteRtLmToolCall>[];
  for (final match in _liteRtTextToolCall.allMatches(text)) {
    final name = match.group(1);
    if (name == null || name.isEmpty) continue;
    calls.add(
      LiteRtLmToolCall(
        name: name,
        arguments: _liteRtTextArguments(match.group(2)),
      ),
    );
  }
  return calls;
}

Map<String, Object?> _liteRtTextArguments(String? body) {
  final arguments = <String, Object?>{};
  final trimmed = body?.trim() ?? '';
  if (trimmed.isEmpty) return arguments;
  for (final part in trimmed.split(',')) {
    final separator = part.indexOf(':');
    if (separator <= 0) continue;
    final key = part.substring(0, separator).trim();
    if (key.isEmpty) continue;
    arguments[key] = _liteRtTextValue(part.substring(separator + 1).trim());
  }
  return arguments;
}

Object _liteRtTextValue(String raw) {
  if (raw == 'true') return true;
  if (raw == 'false') return false;
  return int.tryParse(raw) ?? raw;
}

typedef LiteRtToolRound =
    Future<LiteRtLmReply> Function({
      required String prompt,
      required List<LiteRtLmToolSpec> tools,
      required List<LiteRtLmToolResponse> toolResponses,
    });

typedef LiteRtToolExecutor =
    Future<String> Function(String name, Map<String, Object?> arguments);

/// Runs lookup tools outside the native runtime.
///
/// LiteRT is asked not to execute tools itself. Each round either returns
/// text or names a tool. This loop runs only the tools it was given, sends
/// the result back, and stops after [maxIterations] executions.
Future<String> completeLiteRtWithTools({
  required LiteRtToolRound generate,
  required LiteRtToolExecutor execute,
  required String prompt,
  required List<LiteRtLmToolSpec> tools,
  int maxIterations = 5,
}) async {
  final allowed = {for (final tool in tools) tool.name};
  var promptForRound = prompt;
  var responses = const <LiteRtLmToolResponse>[];
  var executed = 0;
  var latestText = '';

  while (executed <= maxIterations) {
    final reply = await generate(
      prompt: promptForRound,
      tools: tools,
      toolResponses: responses,
    );
    latestText = reply.text;
    if (reply.toolCalls.isEmpty) {
      final written = liteRtTextToolCalls(reply.text);
      if (written.isEmpty) return latestText;
      return _executeTextToolCalls(
        calls: written,
        allowed: allowed,
        execute: execute,
        executed: executed,
        maxIterations: maxIterations,
      );
    }
    if (executed >= maxIterations) {
      return latestText.trim().isNotEmpty
          ? latestText
          : kLiteRtToolBudgetMessage;
    }

    final next = <LiteRtLmToolResponse>[];
    for (final call in reply.toolCalls) {
      if (executed >= maxIterations) {
        return latestText.trim().isNotEmpty
            ? latestText
            : kLiteRtToolBudgetMessage;
      }
      final output = allowed.contains(call.name)
          ? await execute(call.name, call.arguments)
          : 'Tool ${call.name} is not available.';
      next.add(LiteRtLmToolResponse(name: call.name, response: output));
      executed += 1;
    }
    promptForRound = '';
    responses = next;
  }

  return latestText.trim().isNotEmpty ? latestText : kLiteRtToolBudgetMessage;
}

Future<String> _executeTextToolCalls({
  required List<LiteRtLmToolCall> calls,
  required Set<String> allowed,
  required LiteRtToolExecutor execute,
  required int executed,
  required int maxIterations,
}) async {
  final lines = <String>[];
  var used = executed;
  for (final call in calls) {
    if (used >= maxIterations) {
      return lines.isNotEmpty ? lines.join('\n') : kLiteRtToolBudgetMessage;
    }
    final output = allowed.contains(call.name)
        ? await execute(call.name, call.arguments)
        : 'Tool ${call.name} is not available.';
    lines.add(_visibleToolOutput(output));
    used += 1;
  }
  return lines.join('\n');
}

String _visibleToolOutput(String output) {
  final trimmed = output.trim();
  if (!trimmed.startsWith('{')) return output;
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is String && message.trim().isNotEmpty) return message;
    }
  } on Object {
    return output;
  }
  return output;
}
