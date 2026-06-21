import 'package:airo_app/features/agent_chat/data/connectors/calendar_connector.dart';
import 'package:airo_app/features/agent_chat/data/connectors/date_time_connector.dart';
import 'package:airo_app/features/agent_chat/domain/models/agent_skill.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_connector.dart';
import 'package:airo_app/features/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AgentConnectorRegistry', () {
    test('dispatches registered connectors by app-owned name', () async {
      final registry = AgentConnectorRegistry(
        connectors: [DateTimeConnector(now: () => DateTime(2026, 6, 20, 9, 3))],
      );

      final result = await registry.execute('get_current_date_time', const {});

      expect(result.isError, false);
      expect(result.data['date'], '2026-06-20');
      expect(result.data['time'], '09:03');
    });

    test('rejects unknown connectors', () async {
      final registry = AgentConnectorRegistry(connectors: const []);

      final result = await registry.execute('delete_everything', const {});

      expect(result.isError, true);
      expect(result.errorCode, 'unknown_connector');
    });

    test('validates connector arguments before dispatch', () async {
      final registry = AgentConnectorRegistry(
        connectors: [InMemoryCalendarConnector()],
      );

      final result = await registry.execute('read_calendar_events', const {});

      expect(result.isError, true);
      expect(result.errorCode, 'missing_date');
    });

    test('does not expose undeclared connector names as callable tools', () {
      final registry = AgentConnectorRegistry(
        connectors: [
          const _FakeConnector('safe_tool'),
          const _FakeConnector('dangerous_tool'),
        ],
      );

      expect(registry.allowedNamesForSkill(const ['safe_tool']), ['safe_tool']);
    });

    test(
      'requires explicit confirmation before creating calendar events',
      () async {
        final registry = AgentConnectorRegistry(
          connectors: [NativeCreateCalendarEventConnector()],
        );

        final result = await registry.execute('create_calendar_event', const {
          'title': 'Design review',
          'start': '2026-06-20T15:00:00+05:30',
          'end': '2026-06-20T16:00:00+05:30',
        });

        expect(result.isError, true);
        expect(result.errorCode, 'confirmation_required');
        expect(result.message, contains('confirm'));
      },
    );

    test('validates create calendar event arguments', () async {
      final registry = AgentConnectorRegistry(
        connectors: [NativeCreateCalendarEventConnector()],
      );

      final result = await registry.execute('create_calendar_event', const {
        'confirmed': true,
        'title': 'Design review',
      });

      expect(result.isError, true);
      expect(result.errorCode, 'invalid_calendar_event');
    });

    test(
      'dispatches confirmed calendar event creation through app channel',
      () async {
        const channel = MethodChannel('com.airo.agent_connectors.test');
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              calls.add(call);
              return <String, dynamic>{
                'created': true,
                'confirmation': 'native',
              };
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null);
        });
        final registry = AgentConnectorRegistry(
          connectors: [NativeCreateCalendarEventConnector(channel: channel)],
        );

        final result = await registry.execute('create_calendar_event', const {
          'confirmed': true,
          'title': 'Design review',
          'start': '2026-06-20T15:00:00+05:30',
          'end': '2026-06-20T16:00:00+05:30',
        });

        expect(result.isError, false);
        expect(result.data['created'], true);
        expect(calls.single.method, 'createCalendarEvent');
        expect(calls.single.arguments, containsPair('title', 'Design review'));
      },
    );
  });
}

class _FakeConnector implements AgentConnector {
  const _FakeConnector(this.name);

  @override
  final String name;

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    return const ConnectorResult(data: {'ok': true});
  }
}
