import 'agent_connector.dart';

class AgentConnectorRegistry {
  AgentConnectorRegistry({required List<AgentConnector> connectors})
    : _connectors = {
        for (final connector in connectors) connector.name: connector,
      };

  final Map<String, AgentConnector> _connectors;

  AgentConnector? getConnector(String name) => _connectors[name];

  List<String> allowedNamesForSkill(List<String> declaredTools) {
    return declaredTools
        .where((name) => _connectors.containsKey(name))
        .toList(growable: false);
  }

  Future<ConnectorResult> execute(
    String name,
    Map<String, dynamic> arguments,
  ) async {
    final connector = _connectors[name];
    if (connector == null) {
      return ConnectorResult.error(
        code: 'unknown_connector',
        message: 'Connector "$name" is not registered.',
      );
    }
    return connector.execute(arguments);
  }
}
