import 'package:feature_assistant/src/agent_chat/domain/services/intent_parser.dart';
import 'package:feature_assistant/src/agent_chat/domain/services/tool_registry.dart';
import 'package:feature_assistant/src/services/device_actions_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ToolRegistry', () {
    late ToolRegistry registry;

    setUp(() {
      registry = ToolRegistry();
    });

    test('exposes Gallery and Off Grid inspired skill cards', () {
      final cards = registry.getSkillCards();
      final titles = cards.map((card) => card.title).toList();

      expect(titles, contains('AI Chat'));
      expect(titles, contains('Agent Skills'));
      expect(titles, contains('Split Bill'));
      expect(titles, contains('Diet Plan'));
      expect(titles, contains('Ask Image'));
      expect(titles, contains('Audio Scribe'));
      expect(titles, contains('Mobile Actions'));
      expect(titles, contains('Tiny Garden'));
      expect(titles, contains('Model Management'));
      expect(titles, contains('Arena Games'));
      expect(
        cards.singleWhere((card) => card.title == 'Ask Image').route,
        '/quest/new',
      );
      expect(
        cards.singleWhere((card) => card.title == 'Audio Scribe').route,
        '/assistant/audio-scribe',
      );
      expect(
        cards.singleWhere((card) => card.title == 'Tiny Garden').route,
        '/assistant/mobile-actions',
      );
    });

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

    test('routes Audio Scribe to its capture workflow', () async {
      final result = await registry.executeIntent(
        IntentParser.parse('transcribe audio'),
      );

      expect(result.route, '/assistant/audio-scribe');
      expect(result.message, contains('on-device capture'));
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

    test(
      'executes the safe Wi-Fi device action through its platform boundary',
      () async {
        const channel = MethodChannel('test.tool-device-actions');
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        messenger.setMockMethodCallHandler(
          channel,
          (call) async => const {'opened': true},
        );

        final result = await DeviceActionsTool(
          service: DeviceActionsService(channel: channel),
        ).handle(IntentParser.parse('open wifi settings'));

        expect(result?.isError, isFalse);
        expect(result?.message, 'Opened Wi-Fi settings.');
      },
    );

    test('executes typed Mobile Actions through the same boundary', () async {
      const channel = MethodChannel('test.tool-device-actions.typed');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(
        channel,
        (call) async => call.method == 'setFlashlight'
            ? const {'changed': true}
            : const {'opened': true},
      );

      final result = await DeviceActionsTool(
        service: DeviceActionsService(channel: channel),
      ).handle(IntentParser.parse('turn flashlight on'));

      expect(result?.isError, isFalse);
      expect(result?.message, 'Turned the flashlight on.');
    });
  });
}
