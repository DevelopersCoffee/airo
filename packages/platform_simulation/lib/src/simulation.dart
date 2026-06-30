class HardwareSimulation {
  HardwareSimulation({
    this.batteryLevel = 1.0,
    this.ramPressure = 0.0,
    this.cpuTopology = const [],
    this.gpuAvailable = true,
    this.thermalThrottling = false,
    this.networkLatencyMs = 20,
    this.storageConstraint = false,
  });

  double batteryLevel;
  double ramPressure;
  List<int> cpuTopology;
  bool gpuAvailable;
  bool thermalThrottling;
  int networkLatencyMs;
  bool storageConstraint;
}

abstract class SimulationController {
  void updateState(HardwareSimulation state);
  HardwareSimulation get currentState;
}
