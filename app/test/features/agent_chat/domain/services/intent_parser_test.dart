import 'package:airo_app/features/agent_chat/domain/services/intent_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntentParser Coins questions', () {
    test('parses @Coins prompts as contextual finance questions', () {
      final intent = IntentParser.parse('@Coins can I save more this month?');

      expect(intent.type, IntentType.coinsQuestion);
      expect(intent.parameters['question'], 'can i save more this month?');
      expect(intent.confidence, 0.9);
    });

    test('parses natural spending insight prompts as Coins questions', () {
      final intent = IntentParser.parse('show my spending insight');

      expect(intent.type, IntentType.coinsQuestion);
      expect(intent.parameters['question'], 'show my spending insight');
    });
  });
}
