import 'package:feature_mind/src/agent_chat/domain/services/chat_turn_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatChatTurnDuration', () {
    test('formats sub-second durations in milliseconds', () {
      expect(formatChatTurnDuration(0), '0ms');
      expect(formatChatTurnDuration(999), '999ms');
    });

    test('formats second-scale durations with one decimal', () {
      expect(formatChatTurnDuration(1000), '1.0s');
      expect(formatChatTurnDuration(1500), '1.5s');
      expect(formatChatTurnDuration(12_345), '12.3s');
    });
  });
}
