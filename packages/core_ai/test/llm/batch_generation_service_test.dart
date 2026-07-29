import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClient implements LLMClient {
  @override
  LLMConfig get config => const LLMConfig(provider: 'fake', modelName: 'fake');

  @override
  int get maxContextLength => 2048;

  @override
  Future<Result<LLMResponse>> generate(String prompt) async {
    if (prompt == 'bad') {
      return Failure(ValidationFailure(message: 'bad prompt'));
    }
    return Success(LLMResponse(text: 'response:$prompt', provider: 'fake'));
  }

  @override
  Stream<String> generateStream(String prompt) async* {
    yield 'response:$prompt';
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  int estimateTokens(String text) => text.length;

  @override
  Future<void> dispose() async {}
}

void main() {
  test(
    'batch generation preserves order and reports per-item failures',
    () async {
      final progress = <String>[];
      final results =
          await BatchGenerationService(
            client: _FakeClient(),
            maxConcurrent: 2,
          ).generate(
            const ['one', 'bad', 'three'],
            onProgress: (completed, total) => progress.add('$completed/$total'),
          );

      expect(results.map((result) => result.index), [0, 1, 2]);
      expect(results[0].succeeded, isTrue);
      expect(results[0].response?.text, 'response:one');
      expect(results[1].succeeded, isFalse);
      expect(results[1].error.toString(), contains('bad prompt'));
      expect(results[2].succeeded, isTrue);
      expect(progress, hasLength(3));
    },
  );

  test('cancellation marks queued work without invoking the client', () async {
    final token = BatchCancellationToken()..cancel();
    final results = await BatchGenerationService(
      client: _FakeClient(),
    ).generate(const ['one', 'two'], cancellation: token);

    expect(
      results,
      everyElement(
        predicate<BatchGenerationResult>((result) {
          return result.cancelled && !result.succeeded;
        }),
      ),
    );
  });
}
