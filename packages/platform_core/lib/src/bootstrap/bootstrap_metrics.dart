class BootstrapMetrics {
  final DateTime startTime;
  DateTime? finishTime;
  final Map<String, Duration> taskDurations = {};
  final List<String> failedTasks = [];
  final List<String> skippedTasks = [];
  int dependencyGraphDepth = 0;

  BootstrapMetrics() : startTime = DateTime.now();

  void markFinished() {
    finishTime = DateTime.now();
  }

  Duration get totalDuration => finishTime?.difference(startTime) ?? Duration.zero;
}
