import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class DateTimeConnector implements AgentConnector {
  DateTimeConnector({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  @override
  String get name => 'get_current_date_time';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final current = _now();
    return ConnectorResult(
      data: {
        'date': _formatDate(current),
        'time': _formatTime(current),
        'timezone': current.timeZoneName,
      },
    );
  }
}

String _formatDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

String _formatTime(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
