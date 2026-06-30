class StreamEvent<T> {
  const StreamEvent.started()
      : type = StreamEventType.started,
        data = null,
        metrics = null,
        message = null;

  const StreamEvent.progress(double progress)
      : type = StreamEventType.progress,
        data = null,
        metrics = progress,
        message = null;

  const StreamEvent.partialResult(T partial)
      : type = StreamEventType.partialResult,
        data = partial,
        metrics = null,
        message = null;

  const StreamEvent.metrics(Map<String, dynamic> m)
      : type = StreamEventType.metrics,
        data = null,
        metrics = m,
        message = null;

  const StreamEvent.warning(String msg)
      : type = StreamEventType.warning,
        data = null,
        metrics = null,
        message = msg;

  const StreamEvent.completed(T result)
      : type = StreamEventType.completed,
        data = result,
        metrics = null,
        message = null;

  const StreamEvent.failed(String error)
      : type = StreamEventType.failed,
        data = null,
        metrics = null,
        message = error;

  const StreamEvent.cancelled()
      : type = StreamEventType.cancelled,
        data = null,
        metrics = null,
        message = null;

  final StreamEventType type;
  final T? data;
  final dynamic metrics;
  final String? message;
}

enum StreamEventType {
  started,
  progress,
  partialResult,
  metrics,
  warning,
  completed,
  failed,
  cancelled,
}
