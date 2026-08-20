import 'package:feature_mind/src/agent_chat/domain/services/intent_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IntentParser', () {
    test(
      'detects split bill requests and extracts amount and participants',
      () {
        final intent = IntentParser.parse(
          'split this ₹2400 bill with Asha, Ben and Chen',
        );

        expect(intent.type, IntentType.splitBill);
        expect(intent.parameters['amountCents'], 240000);
        expect(intent.parameters['currencyCode'], 'INR');
        expect(intent.parameters['participants'], ['Asha', 'Ben', 'Chen']);
      },
    );

    test('detects diet plan requests and preserves the original prompt', () {
      final intent = IntentParser.parse('make me a 7 day vegetarian diet plan');

      expect(intent.type, IntentType.createDietPlan);
      expect(
        intent.parameters['prompt'],
        'make me a 7 day vegetarian diet plan',
      );
      expect(intent.parameters['dietStyle'], 'vegetarian');
    });

    test('treats a non-veg follow-up as a diet plan refinement', () {
      final intent = IntentParser.parse('non veg only');

      expect(intent.type, IntentType.createDietPlan);
      expect(intent.parameters['dietStyle'], 'nonVegetarian');
    });

    test('treats veg only as a diet plan refinement', () {
      final intent = IntentParser.parse('veg only');

      expect(intent.type, IntentType.createDietPlan);
      expect(intent.parameters['dietStyle'], 'vegetarian');
    });

    test('detects routine planning requests', () {
      final intent = IntentParser.parse(
        'create a morning study routine for tomorrow',
      );

      expect(intent.type, IntentType.createRoutine);
      expect(
        intent.parameters['prompt'],
        'create a morning study routine for tomorrow',
      );
    });

    test(
      'routes boredom and game requests to Airo Arena instead of Tiny Garden',
      () {
        final intent = IntentParser.parse('I am bored, start chess');

        expect(intent.type, IntentType.playGame);
        expect(intent.parameters['game'], 'chess');
      },
    );

    test('detects Gallery and Off Grid inspired AI use cases', () {
      expect(
        IntentParser.parse('ask image about this receipt').type,
        IntentType.askImage,
      );
      expect(
        IntentParser.parse('audio scribe this recording').type,
        IntentType.audioScribe,
      );
      expect(
        IntentParser.parse('open mobile actions').type,
        IntentType.mobileActions,
      );
      expect(
        IntentParser.parse('open Wi-Fi settings').type,
        IntentType.openWifiSettings,
      );
      expect(
        IntentParser.parse('turn the flashlight off').type,
        IntentType.setFlashlight,
      );
      expect(
        IntentParser.parse('turn the flashlight off').parameters['enabled'],
        false,
      );
      expect(
        IntentParser.parse('create contact').type,
        IntentType.createContact,
      );
      expect(
        IntentParser.parse('show location on map').type,
        IntentType.openMap,
      );
      expect(
        IntentParser.parse('manage offline models').type,
        IntentType.modelManagement,
      );
      expect(IntentParser.parse('give me mom').type, IntentType.getMeetingMom);
      expect(
        IntentParser.parse('minutes for standup').type,
        IntentType.getMeetingMom,
      );
    });
  });
}
