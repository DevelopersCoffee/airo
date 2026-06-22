import 'package:airo_app/features/agent_chat/domain/services/intent_parser.dart';
import 'package:airo_app/features/agent_chat/domain/services/tool_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
    });

    test(
      'exposes Gallery and Off Grid inspired skill cards without Tiny Garden',
      () {
        final cards = registry.getSkillCards();
        final titles = cards.map((card) => card.title).toList();

        expect(titles, contains('AI Chat'));
        expect(titles, contains('Agent Skills'));
        expect(titles, contains('Split Bill'));
        expect(titles, contains('Diet Plan'));
        expect(titles, contains('Live Notes'));
        expect(titles, contains('Mobile Actions'));
        expect(titles, contains('Model Management'));
        expect(titles, contains('Arena Games'));
        expect(titles, isNot(contains('Tiny Garden')));
      },
    );

    test(
      'splits bills directly in chat when amount and participants exist',
      () async {
        final result = await registry.executeIntent(
          IntentParser.parse('split this ₹2400 bill with Asha, Ben and Chen'),
        );

        expect(result.shouldNavigate, false);
        expect(result.message, contains('₹800.00'));
        expect(result.message, contains('Asha'));
        expect(result.message, contains('Ben'));
        expect(result.message, contains('Chen'));
      },
    );

    test('creates diet and routine drafts inside chat', () async {
      final diet = await registry.executeIntent(
        IntentParser.parse('make me a 7 day vegetarian diet plan'),
      );
      final routine = await registry.executeIntent(
        IntentParser.parse('create a study routine for tomorrow'),
      );

      expect(diet.message, contains('7-day diet plan'));
      expect(routine.message, contains('routine'));
      expect(diet.shouldNavigate, false);
      expect(routine.shouldNavigate, false);
    });

    test('routes game and model management requests to Airo screens', () async {
      final game = await registry.executeIntent(
        IntentParser.parse('start chess'),
      );
      final models = await registry.executeIntent(
        IntentParser.parse('manage offline models'),
      );

      expect(game.route, '/games');
      expect(game.message, contains('Arena'));
      expect(game.parameters['game'], 'chess');
      expect(models.route, '/agent/profile');
      expect(models.message, contains('Profile model settings'));
    });

    test('routes live notes into the Assistant planning surface', () async {
      final result = await registry.executeIntent(
        IntentParser.parse('start live notes for this team discussion'),
      );

      expect(result.route, '/agent/live-notes');
      expect(result.message, contains('Live Notes'));
      expect(result.message, contains('listen'));
    });
  });
}
