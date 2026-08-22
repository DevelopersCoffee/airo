import 'package:core_ai/core_ai.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_connector.dart';

class DeviceEnvironmentConnector implements AgentConnector {
  DeviceEnvironmentConnector({Future<MemoryInfo> Function()? loadMemory})
    : _loadMemory = loadMemory ?? _defaultLoadMemory;

  final Future<MemoryInfo> Function() _loadMemory;

  @override
  String get name => 'get_device_environment_telemetry';

  @override
  Set<SkillCapability> get requiredCapabilities => const {};

  @override
  Future<ConnectorResult> execute(Map<String, dynamic> arguments) async {
    final memory = await _loadMemory();
    if (!memory.isAvailable) {
      return const ConnectorResult.error(
        code: 'telemetry_unavailable',
        message: 'Device memory telemetry is not available on this host.',
      );
    }
    return ConnectorResult(
      data: {
        'available_memory_mb': memory.availableMB.round(),
        'total_memory_mb': memory.totalMB.round(),
        'available_memory_gb': double.parse(
          memory.availableGB.toStringAsFixed(2),
        ),
        'total_memory_gb': double.parse(memory.totalGB.toStringAsFixed(2)),
      },
    );
  }
}

Future<MemoryInfo> _defaultLoadMemory() {
  return DeviceCapabilityService().getMemoryInfo(forceRefresh: true);
}
