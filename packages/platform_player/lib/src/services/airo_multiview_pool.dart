import 'dart:async';

const int kAiroMultiviewHardCap = 4;

/// One independently owned playback session in a bounded multiview pool.
///
/// Implementations must absorb backend volume/cleanup failures so the pool can
/// preserve its single-audible-session invariant without throwing into UI.
abstract interface class AiroMultiviewSession {
  String get id;

  Future<void> setAudible(bool audible);

  Future<void> close();
}

enum AiroMultiviewAddResult {
  added,
  alreadyPresent,
  capacityReached,
  openFailed,
}

class AiroMultiviewPoolState {
  const AiroMultiviewPoolState({
    this.sessions = const [],
    this.featuredSessionId,
  });

  final List<AiroMultiviewSession> sessions;
  final String? featuredSessionId;

  int get count => sessions.length;

  bool contains(String id) => sessions.any((session) => session.id == id);
}

/// Owns at most [capacity] playback sessions and routes audio exclusively to
/// the featured session.
class AiroMultiviewPool {
  AiroMultiviewPool({required int decoderBudget, this.onChanged})
    : capacity = decoderBudget.clamp(1, kAiroMultiviewHardCap);

  final int capacity;
  final void Function(AiroMultiviewPoolState state)? onChanged;
  final Set<String> _pendingIds = {};
  AiroMultiviewPoolState _state = const AiroMultiviewPoolState();
  bool _closed = false;

  AiroMultiviewPoolState get state => _state;

  Future<AiroMultiviewAddResult> add({
    required String id,
    required Future<AiroMultiviewSession> Function() openSession,
  }) async {
    if (_closed) return AiroMultiviewAddResult.openFailed;
    if (_state.contains(id) || _pendingIds.contains(id)) {
      return AiroMultiviewAddResult.alreadyPresent;
    }
    if (_state.count + _pendingIds.length >= capacity) {
      return AiroMultiviewAddResult.capacityReached;
    }

    _pendingIds.add(id);
    AiroMultiviewSession? session;
    try {
      session = await openSession();
      if (_closed) {
        await _closeSafely(session);
        return AiroMultiviewAddResult.openFailed;
      }
      if (session.id != id) {
        await _closeSafely(session);
        return AiroMultiviewAddResult.openFailed;
      }
      await session.setAudible(false);
      final sessions = List<AiroMultiviewSession>.unmodifiable([
        ..._state.sessions,
        session,
      ]);
      final featured = _state.featuredSessionId ?? id;
      _setState(
        AiroMultiviewPoolState(sessions: sessions, featuredSessionId: featured),
      );
      await _routeAudio(featured);
      return AiroMultiviewAddResult.added;
    } catch (_) {
      if (session != null) await _closeSafely(session);
      return AiroMultiviewAddResult.openFailed;
    } finally {
      _pendingIds.remove(id);
    }
  }

  Future<void> promote(String id) async {
    if (_closed || !_state.contains(id) || _state.featuredSessionId == id) {
      return;
    }
    await _routeAudio(id);
    _setState(
      AiroMultiviewPoolState(sessions: _state.sessions, featuredSessionId: id),
    );
  }

  Future<void> remove(String id) async {
    if (_closed) return;
    AiroMultiviewSession? removed;
    final remaining = <AiroMultiviewSession>[];
    for (final session in _state.sessions) {
      if (session.id == id) {
        removed = session;
      } else {
        remaining.add(session);
      }
    }
    if (removed == null) return;

    final featured = _state.featuredSessionId == id
        ? remaining.firstOrNull?.id
        : _state.featuredSessionId;
    _setState(
      AiroMultiviewPoolState(
        sessions: List.unmodifiable(remaining),
        featuredSessionId: featured,
      ),
    );
    await removed.setAudible(false);
    await _closeSafely(removed);
    if (featured != null) await _routeAudio(featured);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final sessions = _state.sessions;
    _setState(const AiroMultiviewPoolState());
    await Future.wait(
      sessions.map((session) async {
        try {
          await session.setAudible(false);
        } catch (_) {
          // Continue closing every owned session.
        }
        await _closeSafely(session);
      }),
    );
  }

  Future<void> _routeAudio(String featuredId) async {
    for (final session in _state.sessions) {
      await session.setAudible(false);
    }
    for (final session in _state.sessions) {
      if (session.id == featuredId) {
        await session.setAudible(true);
        break;
      }
    }
  }

  Future<void> _closeSafely(AiroMultiviewSession session) async {
    try {
      await session.close();
    } catch (_) {
      // One broken backend must not leak the remaining sessions.
    }
  }

  void _setState(AiroMultiviewPoolState state) {
    _state = state;
    onChanged?.call(state);
  }
}
