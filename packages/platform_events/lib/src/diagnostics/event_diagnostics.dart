class EventBusDiagnostics {
  final int activeSubscribers;
  final int publishedCount;
  final int droppedCount;

  const EventBusDiagnostics({
    required this.activeSubscribers,
    required this.publishedCount,
    required this.droppedCount,
  });
}
