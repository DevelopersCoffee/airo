import 'package:meta/meta.dart';

import 'llm_client.dart';
import 'llm_response.dart';

/// Cooperative cancellation token for background or batch inference.
class BatchCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() => _cancelled = true;
}

@immutable
class BatchGenerationResult {
  const BatchGenerationResult({
    required this.index,
    required this.prompt,
    this.response,
    this.error,
    this.cancelled = false,
  });

  final int index;
  final String prompt;
  final LLMResponse? response;
  final Object? error;
  final bool cancelled;

  bool get succeeded => response != null && error == null && !cancelled;
}

typedef BatchProgressCallback = void Function(int completed, int total);

/// Runs independent prompts with bounded concurrency and deterministic order.
class BatchGenerationService {
  BatchGenerationService({required this._client, int maxConcurrent = 1})
    : maxConcurrent = maxConcurrent.clamp(1, 32).toInt();

  final LLMClient _client;
  final int maxConcurrent;

  Future<List<BatchGenerationResult>> generate(
    List<String> prompts, {
    BatchCancellationToken? cancellation,
    BatchProgressCallback? onProgress,
  }) async {
    if (prompts.isEmpty) return const [];

    final results = List<BatchGenerationResult?>.filled(prompts.length, null);
    var nextIndex = 0;
    var completed = 0;

    Future<void> worker() async {
      while (true) {
        final index = nextIndex++;
        if (index >= prompts.length) return;
        final prompt = prompts[index];

        if (cancellation?.isCancelled ?? false) {
          results[index] = BatchGenerationResult(
            index: index,
            prompt: prompt,
            cancelled: true,
          );
        } else {
          try {
            final result = await _client.generate(prompt);
            results[index] = result.isOk
                ? BatchGenerationResult(
                    index: index,
                    prompt: prompt,
                    response: result.getOrNull(),
                  )
                : BatchGenerationResult(
                    index: index,
                    prompt: prompt,
                    error: result.getErrorOrNull(),
                  );
          } catch (error) {
            results[index] = BatchGenerationResult(
              index: index,
              prompt: prompt,
              error: error,
            );
          }
        }

        completed++;
        onProgress?.call(completed, prompts.length);
      }
    }

    final workerCount = maxConcurrent < prompts.length
        ? maxConcurrent
        : prompts.length;
    await Future.wait(List.generate(workerCount, (_) => worker()));
    return results.cast<BatchGenerationResult>();
  }
}
