import 'package:core_completion/core_completion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FakeCompletionClient streams tokens and records grammar', () async {
    final client = FakeCompletionClient(tokens: ['{', '"ok"', '}']);
    expect(client.isAvailable, isTrue);
    final chunks = <String>[];
    await for (final token in client.generate(
      prompt: 'hello',
      grammar: 'root ::= object',
      maxTokens: 64,
    )) {
      chunks.add(token);
    }
    expect(chunks, ['{', '"ok"', '}']);
    expect(client.lastPrompt, 'hello');
    expect(client.lastGrammar, 'root ::= object');
    expect(client.lastMaxTokens, 64);
  });

  test('FakeCompletionClient can throw a scripted error', () async {
    final client = FakeCompletionClient(
      error: const CompletionUnavailable('gguf_model_not_loaded'),
    );
    expect(
      client.generate(prompt: 'x'),
      emitsError(isA<CompletionUnavailable>()),
    );
  });
}
