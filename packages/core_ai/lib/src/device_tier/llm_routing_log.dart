import 'dart:async';

import 'llm_routing_decision.dart';

/// An in-memory, inspectable record of recent routing decisions.
///
/// Deliberately *not* a persistent store. `feature_mind`'s `MindRuntime` has
/// a real append-only, signature-verified audit log
/// (`OperationLogPort`/`MindOpKind`) that would be the right home for a
/// durable "why local vs cloud" trail -- but it is still a `MindPortUnavailable`
/// stub pending `#1213`-`#1216` (Track A, milestone 19's runtime freeze).
/// This class is the interim, in-process seam #1631 needs today: a bounded
/// ring buffer plus a broadcast stream a diagnostics screen or console can
/// subscribe to. When the operation log lands, routing decisions should
/// additionally be appended there as a `MindOpKind` case rather than this
/// class growing a persistence layer of its own.
class LlmRoutingLog {
  LlmRoutingLog({this.maxEntries = 200}) : assert(maxEntries > 0);

  final int maxEntries;
  final List<LlmRoutingDecision> _entries = [];
  final StreamController<LlmRoutingDecision> _controller =
      StreamController<LlmRoutingDecision>.broadcast();

  /// Emits every decision as it is recorded -- the seam a live inspector UI
  /// subscribes to.
  Stream<LlmRoutingDecision> get onDecision => _controller.stream;

  void record(LlmRoutingDecision decision) {
    _entries.add(decision);
    if (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
    if (!_controller.isClosed) {
      _controller.add(decision);
    }
  }

  /// Most recent decisions first, newest at index 0, capped at [limit].
  List<LlmRoutingDecision> recent({int limit = 50}) {
    final newestFirst = _entries.reversed.toList(growable: false);
    if (newestFirst.length <= limit) return List.unmodifiable(newestFirst);
    return List.unmodifiable(newestFirst.take(limit));
  }

  int get length => _entries.length;

  void dispose() {
    if (!_controller.isClosed) {
      _controller.close();
    }
  }
}
