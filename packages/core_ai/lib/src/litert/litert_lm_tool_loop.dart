import 'litert_lm_runtime_adapter.dart';

const kLiteRtToolBudgetMessage =
    'This request needed too many steps. Try a simpler question.';

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
    if (reply.toolCalls.isEmpty) return latestText;
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
