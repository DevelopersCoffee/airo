import 'dart:async';
import '../models/haptic_intent.dart';

/// Request item queued in coalescer.
class AiroHapticRequest {
  const AiroHapticRequest({
    required this.key,
    required this.priority,
    required this.action,
  });

  final String key;
  final AiroHapticPriority priority;
  final Future<void> Function() action;
}

/// Coalesces rapid high-frequency haptic requests within a frame or short interval window.
class AiroHapticCoalescer {
  AiroHapticCoalescer({this.interval = const Duration(milliseconds: 16)});

  final Duration interval;
  Timer? _timer;
  AiroHapticRequest? _pending;

  /// Submits a request for execution. If another request arrives within [interval],
  /// the higher-priority request is preserved.
  void submit(AiroHapticRequest request) {
    if (_pending == null || request.priority >= _pending!.priority) {
      _pending = request;
    }

    _timer ??= Timer(interval, _flush);
  }

  void _flush() {
    final req = _pending;
    _pending = null;
    _timer?.cancel();
    _timer = null;

    if (req != null) {
      req.action();
    }
  }

  /// Cancels any pending coalesced request.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
