import 'package:feature_mind/src/agent_chat/domain/services/chat_turn_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatChatTurnDuration', () {
    test('formats sub-second durations in milliseconds', () {
      expect(formatChatTurnDuration(0), '0ms');
      expect(formatChatTurnDuration(1), '1ms');
      expect(formatChatTurnDuration(999), '999ms');
    });

    test('formats second-scale durations with one decimal', () {
      expect(formatChatTurnDuration(1000), '1.0s');
      expect(formatChatTurnDuration(1500), '1.5s');
      expect(formatChatTurnDuration(12_345), '12.3s');
      expect(formatChatTurnDuration(60_000), '60.0s');
      expect(formatChatTurnDuration(3_600_000), '3600.0s');
    });

    test('pins ms versus seconds boundary used by chat UI call sites', () {
      expect(formatChatTurnDuration(999), '999ms');
      expect(formatChatTurnDuration(1000), '1.0s');
    });

    test('preserves negative millisecond values when passed through', () {
      expect(formatChatTurnDuration(-1), '-1ms');
      expect(formatChatTurnDuration(-1500), '-1500ms');
    });
  });
}
