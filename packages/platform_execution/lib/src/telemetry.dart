class HardwareState {
  const HardwareState({
    this.batteryLevel = 1.0,
    this.isCharging = true,
    this.availableRamKb = 0,
    this.cpuUtilization = 0.0,
    this.gpuUtilization = 0.0,
    this.temperatureCelcius = 0.0,
  });

  final double batteryLevel;
  final bool isCharging;
  final int availableRamKb;
  final double cpuUtilization;
  final double gpuUtilization;
  final double temperatureCelcius;
}

abstract class RuntimeTelemetry {
  Future<HardwareState> getCurrentState();
}

abstract class TelemetryHistoryService {
  Future<Map<String, dynamic>> getHistoricalBenchmarks(String providerId);
}
