import 'package:feature_mind/src/agent_chat/domain/models/chat_transcript_turn.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('round-trips a Cursor-shaped JSONL line', () {
    final turn = ChatTranscriptTurn(
      role: 'user',
      text: 'Niva Bupa Claim ID 9001001',
      createdAt: DateTime.utc(2026, 8, 21, 18, 51),
    );

    final parsed = ChatTranscriptTurn.parseLines('${turn.toJsonl()}\n');
    expect(parsed, hasLength(1));
    expect(parsed.single.role, 'user');
    expect(parsed.single.text, 'Niva Bupa Claim ID 9001001');
  });

  test('title comes from the first user line', () {
    final title = MindChatRecord.titleFromTurns([
      ChatTranscriptTurn(
        role: 'assistant',
        text: 'Hi',
        createdAt: DateTime.utc(2026, 8, 21),
      ),
      ChatTranscriptTurn(
        role: 'user',
        text: 'Track this claim after hospital',
        createdAt: DateTime.utc(2026, 8, 21),
      ),
    ]);
    expect(title, 'Track this claim after hospital');
  });
}
