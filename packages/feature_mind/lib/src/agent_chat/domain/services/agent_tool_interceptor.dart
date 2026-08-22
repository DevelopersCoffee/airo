import 'agent_connector.dart';
import 'agent_connector_registry.dart';

/// Rule-based interceptor: execution tools run before the LLM.
///
/// Compact local models skip the JSON skill router, so perception and math
/// must not wait on the cognitive core.
class AgentToolInterceptor {
  const AgentToolInterceptor({required this.connectors});

  final AgentConnectorRegistry connectors;

  Future<AgentToolInterceptResult?> handle(String prompt) async {
    final trimmed = prompt.trim();
    if (trimmed.isEmpty) return null;

    final arithmetic = _tryArithmetic(trimmed);
    if (arithmetic != null) return arithmetic;

    final tool = _matchPerceptionTool(trimmed);
    if (tool == null) return null;

    final result = await connectors.execute(tool, const {});
    if (result.isError) {
      return AgentToolInterceptResult(
        tool: tool,
        message: result.message ?? 'That device reading is not available.',
        isError: true,
      );
    }
    return AgentToolInterceptResult(
      tool: tool,
      message: _formatPerception(tool, result.data),
    );
  }

  static String? _matchPerceptionTool(String prompt) {
    final lower = prompt.toLowerCase();
    if (_looksLikeMemory(lower)) return 'get_device_environment_telemetry';
    if (_looksLikeLocalization(lower)) return 'read_system_localization';
    if (_looksLikeTime(lower)) return 'get_current_date_time';
    return null;
  }

  static bool _looksLikeMemory(String lower) {
    return lower.contains('memory') ||
        lower.contains('ram') ||
        (lower.contains('available') &&
            (lower.contains('storage') || lower.contains('battery')));
  }

  static bool _looksLikeLocalization(String lower) {
    return lower.contains('locale') ||
        lower.contains('language') && lower.contains('system') ||
        lower.contains('what currency');
  }

  static bool _looksLikeTime(String lower) {
    return lower.contains('current time') ||
        lower.contains('what time') ||
        lower.contains('time is it') ||
        lower.contains("today's date") ||
        lower.contains('todays date') ||
        lower.contains('what date') ||
        lower.contains('which date') ||
        lower.contains('which day') ||
        lower.contains('what day') ||
        lower.contains('day of the week') ||
        lower.contains('day is it') ||
        lower.contains('day is today') ||
        (lower.contains('today is') &&
            (lower.contains('day') || lower.contains('date'))) ||
        lower.contains('timezone');
  }

  static AgentToolInterceptResult? _tryArithmetic(String prompt) {
    final match = RegExp(
      r'^(\d+(?:\.\d+)?)\s*([+\-*/])\s*(\d+(?:\.\d+)?)\s*\??$',
    ).firstMatch(prompt.replaceAll(' ', ''));
    // Allow spaces: re-match on original with spaces
    final spaced = RegExp(
      r'^(\d+(?:\.\d+)?)\s*([+\-*/])\s*(\d+(?:\.\d+)?)\s*\??$',
    ).firstMatch(prompt);
    final used = spaced ?? match;
    if (used == null) return null;
    final left = double.parse(used.group(1)!);
    final op = used.group(2)!;
    final right = double.parse(used.group(3)!);
    if (op == '/' && right == 0) {
      return const AgentToolInterceptResult(
        tool: 'execute_mathematical_formula',
        message: 'Cannot divide by zero.',
        isError: true,
      );
    }
    final value = switch (op) {
      '+' => left + right,
      '-' => left - right,
      '*' => left * right,
      '/' => left / right,
      _ => null,
    };
    if (value == null) return null;
    final rendered = value == value.roundToDouble()
        ? value.round().toString()
        : value.toString();
    return AgentToolInterceptResult(
      tool: 'execute_mathematical_formula',
      message: rendered,
    );
  }

  static String _formatPerception(String tool, Map<String, dynamic> data) {
    switch (tool) {
      case 'get_current_date_time':
        final date = data['date'];
        final time = data['time'];
        final weekday = data['weekday'];
        final timezone = data['timezone'];
        return 'It is $time on $weekday, $date ($timezone).';
      case 'get_device_environment_telemetry':
        final availableGb = data['available_memory_gb'];
        final totalGb = data['total_memory_gb'];
        return 'About $availableGb GB available of $totalGb GB total memory.';
      case 'read_system_localization':
        return 'System locale is ${data['locale']}.';
      default:
        return data.toString();
    }
  }
}

class AgentToolInterceptResult {
  const AgentToolInterceptResult({
    required this.tool,
    required this.message,
    this.isError = false,
  });

  final String tool;
  final String message;
  final bool isError;
}
