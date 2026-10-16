import 'package:feature_mind/src/agent_chat/data/connectors/calendar_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/reasoning/google_mobile_action_tools.dart';
import 'package:feature_mind/src/services/device_actions_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('calendar datetime maps onto date, hour, and minute', () {
    expect(
      googleCalendarArguments({
        'title': 'Lunch',
        'datetime': '2026-10-16T13:05:00',
      }),
      {'title': 'Lunch', 'date': '2026-10-16', 'hour': 13, 'minute': 5},
    );
  });

  test('Google tools open the matching device action', () async {
    const channel = MethodChannel('test.google.actions');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'setFlashlight'
          ? const {'changed': true}
          : const {'opened': true};
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final actions = DeviceActionsService(channel: channel);
    final registry = AgentConnectorRegistry(
      connectors: [InMemoryCreateCalendarEventConnector()],
    );

    expect(
      await executeGoogleMobileAction(
        actions: actions,
        registry: registry,
        name: 'turn_off_flashlight',
        arguments: const {},
      ),
      'Turned the flashlight off.',
    );
    expect(
      await executeGoogleMobileAction(
        actions: actions,
        registry: registry,
        name: 'send_email',
        arguments: const {
          'to': 'ada@example.com',
          'subject': 'Notes',
          'body': 'Hello',
        },
      ),
      'Opened the email composer.',
    );
    expect(
      await executeGoogleMobileAction(
        actions: actions,
        registry: registry,
        name: 'show_map',
        arguments: const {'query': 'Kyoto station'},
      ),
      'Opened the map.',
    );

    expect(calls.map((call) => call.method), [
      'setFlashlight',
      'composeEmail',
      'openMap',
    ]);
    expect(calls[1].arguments['to'], 'ada@example.com');
    expect(calls[2].arguments['query'], 'Kyoto station');
  });

  test('the seven Google tool names are the published set', () {
    expect(kGoogleMobileActionToolSpecs.map((tool) => tool.name), [
      'turn_on_flashlight',
      'turn_off_flashlight',
      'create_contact',
      'send_email',
      'show_map',
      'open_wifi_settings',
      'create_calendar_event',
    ]);
  });
}
