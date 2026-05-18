import 'package:airo_app/features/agent_chat/domain/services/intent_parser.dart';
import 'package:airo_app/features/agent_chat/domain/services/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolRegistry Coins agent', () {
    test(
      'answers @Coins questions with safe read-only finance guidance',
      () async {
        final result = await ToolRegistry().handleIntent(
          const Intent(
            type: IntentType.coinsQuestion,
            originalText: '@Coins can I save more this month?',
            parameters: {'question': 'can i save more this month?'},
          ),
        );

        expect(result, isNotNull);
        expect(result!.route, '/money');
        expect(result.message, contains('Coins can review your spending'));
        expect(result.message, contains('read-only'));
        expect(
          result.message,
          contains('not a replacement for professional financial advice'),
        );
      },
    );
  });
}
