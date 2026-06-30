abstract class ExecutionPolicy {
  String get name;
  int get weight;
}

class PerformancePolicy implements ExecutionPolicy {
  @override final String name = 'performance';
  @override final int weight = 10;
}

class BatterySaverPolicy implements ExecutionPolicy {
  @override final String name = 'battery_saver';
  @override final int weight = 10;
}

class LowMemoryPolicy implements ExecutionPolicy {
  @override final String name = 'low_memory';
  @override final int weight = 10;
}

class OfflinePolicy implements ExecutionPolicy {
  @override final String name = 'offline';
  @override final int weight = 10;
}

class InteractivePolicy implements ExecutionPolicy {
  @override final String name = 'interactive';
  @override final int weight = 10;
}

class BackgroundPolicy implements ExecutionPolicy {
  @override final String name = 'background';
  @override final int weight = 10;
}

class RealtimePolicy implements ExecutionPolicy {
  @override final String name = 'realtime';
  @override final int weight = 10;
}
