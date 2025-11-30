import 'package:core_domain/core_domain.dart';
import '../client/llm_client.dart';
import 'prompt_template.dart';
import 'prompt_logger.dart';

/// Executes prompts with logging and error handling.
///
/// Combines prompt templates, LLM clients, and logging for
/// a complete prompt execution pipeline.
class PromptExecutor {
  final LLMClient client;
  final PromptLogger? logger;
  final String providerName;

  /// Counter for generating unique execution IDs.
  int _executionCounter = 0;

  PromptExecutor({
    required this.client,
    this.logger,
    this.providerName = 'unknown',
  });

  /// Generate a unique execution ID.
  String _generateExecutionId() {
    _executionCounter++;
    return '${DateTime.now().millisecondsSinceEpoch}_$_executionCounter';
  }

  /// Execute a prompt template with variables.
  Future<Result<String>> execute(
    PromptTemplate prompt,
    Map<String, dynamic> variables, {
    GenerationConfig? config,
    Map<String, dynamic>? metadata,
  }) async {
    final executionId = _generateExecutionId();
    final renderedPrompt = prompt.render(variables);
    final startTime = DateTime.now();

    try {
      // Build config from prompt template if not provided
      final effectiveConfig =
          config ??
          GenerationConfig(
            maxOutputTokens: prompt.maxTokens ?? 1024,
            temperature: prompt.temperature ?? 0.7,
          );

      final result = await client.generateText(
        renderedPrompt,
        config: effectiveConfig,
      );

      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;

      // Log the execution
      if (logger != null) {
        final logEntry = PromptExecutionLog(
          executionId: executionId,
          promptId: prompt.id,
          promptVersion: prompt.version,
          variables: variables,
          renderedPrompt: renderedPrompt,
          response: result.getOrNull()?.content,
          success: result.isOk,
          errorMessage: result.isErr
              ? (result.getErrorOrNull()?.toString() ?? 'Unknown error')
              : null,
          durationMs: durationMs,
          timestamp: startTime,
          provider: providerName,
          metadata: metadata ?? {},
        );
        await logger!.log(logEntry);
      }

      return result.map((r) => r.content);
    } catch (e, s) {
      final endTime = DateTime.now();
      final durationMs = endTime.difference(startTime).inMilliseconds;

      // Log the failure
      if (logger != null) {
        final logEntry = PromptExecutionLog(
          executionId: executionId,
          promptId: prompt.id,
          promptVersion: prompt.version,
          variables: variables,
          renderedPrompt: renderedPrompt,
          response: null,
          success: false,
          errorMessage: e.toString(),
          durationMs: durationMs,
          timestamp: startTime,
          provider: providerName,
          metadata: metadata ?? {},
        );
        await logger!.log(logEntry);
      }

      return Err(e, s);
    }
  }

  /// Execute a prompt and parse the result as JSON.
  Future<Result<Map<String, dynamic>>> executeJson(
    PromptTemplate prompt,
    Map<String, dynamic> variables, {
    GenerationConfig? config,
    Map<String, dynamic>? metadata,
  }) async {
    final result = await execute(
      prompt,
      variables,
      config: config,
      metadata: metadata,
    );

    return result.flatMap((content) {
      try {
        // Try to extract JSON from the response
        final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(content);
        if (jsonMatch == null) {
          return Err(
            ParseError('No JSON found in response'),
            StackTrace.current,
          );
        }

        // Note: In a real implementation, you'd use dart:convert
        // For now, return a placeholder indicating JSON parsing needed
        return Err(
          ParseError('JSON parsing not implemented in pure Dart package'),
          StackTrace.current,
        );
      } catch (e, s) {
        return Err(ParseError('Failed to parse JSON: $e'), s);
      }
    });
  }
}
