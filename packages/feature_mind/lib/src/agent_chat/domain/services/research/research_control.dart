import 'dart:async';

/// Pause / resume / cancel for one research job. Not a prompt.
class ResearchControl {
  bool _paused = false;
  bool _cancelled = false;
  Completer<void> _gate = Completer<void>()..complete();

  bool get isPaused => _paused;
  bool get isCancelled => _cancelled;

  void pause() {
    if (_cancelled || _paused) {
      return;
    }
    _paused = true;
    _gate = Completer<void>();
  }

  void resume() {
    if (_cancelled) {
      return;
    }
    _paused = false;
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  void cancel() {
    _cancelled = true;
    _paused = false;
    if (!_gate.isCompleted) {
      _gate.complete();
    }
  }

  Future<void> barrier() async {
    while (_paused && !_cancelled) {
      await _gate.future;
    }
  }
}
