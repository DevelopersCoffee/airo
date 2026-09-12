import 'package:core_completion/core_completion.dart';
import 'package:flutter_test/flutter_test.dart';

class _ReadyBackend implements GgufNativeBackend {
  String? prompt;
  String? grammar;
  int? maxTokens;

  @override
  bool get isReady => true;

  @override
  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    String? grammar,
  }) {
    this.prompt = prompt;
    this.grammar = grammar;
    this.maxTokens = maxTokens;
    return Stream.fromIterable(const ['ok']);
  }

  @override
  Future<void> stop() async {}
}

class _IdleBackend implements GgufNativeBackend {
  @override
  bool get isReady => false;

  @override
  Stream<String> generate({
    required String prompt,
    required int maxTokens,
    String? grammar,
  }) => Stream.error(StateError('should not run'));

  @override
  Future<void> stop() async {}
}

void main() {
  test(
    'GgufCompletionClient forwards prompt, grammar, and maxTokens',
    () async {
      final native = _ReadyBackend();
      final client = GgufCompletionClient(native: native);
      expect(client.isAvailable, isTrue);
      expect(
        await client
            .generate(
              prompt: 'fix json',
              grammar: 'root ::= object',
              maxTokens: 128,
            )
            .toList(),
        ['ok'],
      );
      expect(native.prompt, 'fix json');
      expect(native.grammar, 'root ::= object');
      expect(native.maxTokens, 128);
    },
  );

  test('unavailable client errors with CompletionUnavailable', () {
    final client = GgufCompletionClient(native: _IdleBackend());
    expect(client.isAvailable, isFalse);
    expect(
      client.generate(prompt: 'x'),
      emitsError(isA<CompletionUnavailable>()),
    );
  });
}
