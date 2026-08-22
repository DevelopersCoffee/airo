import 'package:feature_mind/src/agent_chat/data/connectors/date_time_connector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_connector_registry.dart';
import 'package:feature_mind/src/agent_chat/domain/services/agent_tool_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AgentToolInterceptor', () {
    test('answers simple arithmetic without the chat model', () async {
      final interceptor = AgentToolInterceptor(
        connectors: AgentConnectorRegistry(
          connectors: [DateTimeConnector(now: () => DateTime(2026, 6, 20))],
        ),
      );

      final result = await interceptor.handle('2+2');

      expect(result?.message, '4');
      expect(result?.isError, false);
    });

    test('leaves capability and calendar prompts alone', () async {
      final interceptor = AgentToolInterceptor(
        connectors: AgentConnectorRegistry(
          connectors: [DateTimeConnector(now: () => DateTime(2026, 6, 20))],
        ),
      );

      expect(await interceptor.handle('what can u do'), isNull);
      expect(await interceptor.handle('list all events'), isNull);
      expect(
        await interceptor.handle('when was the last time model is trained'),
        isNull,
      );
    });

    test('answers which-day and date questions from the clock', () async {
      final interceptor = AgentToolInterceptor(
        connectors: AgentConnectorRegistry(
          connectors: [
            DateTimeConnector(now: () => DateTime(2026, 8, 21, 23, 45, 46)),
          ],
        ),
      );

      final whichDay = await interceptor.handle('today is which day ?');
      expect(whichDay?.tool, 'get_current_date_time');
      expect(whichDay?.message, contains('Friday'));
      expect(whichDay?.message, contains('2026-08-21'));

      final date = await interceptor.handle('what is todays date ?');
      expect(date?.message, contains('Friday'));
    });
  });
}
