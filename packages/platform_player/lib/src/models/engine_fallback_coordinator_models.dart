import 'dart:async';

import 'package:equatable/equatable.dart';

import 'playback_engine_models.dart';
import '../services/airo_playback_engine.dart';

enum AiroEngineFallbackDecisionCode {
  openedOnPrimary('opened_on_primary'),
  switchedToFallback('switched_to_fallback'),
  exhausted('exhausted'),
  delegatedToSourceFailover('delegated_to_source_failover'),
  ignoredLocked('ignored_locked');

  const AiroEngineFallbackDecisionCode(this.stableId);

  final String stableId;
}

class AiroEngineFallbackDecision extends Equatable {
  const AiroEngineFallbackDecision({
    required this.code,
    required this.state,
    required this.engineKind,
  });

  final AiroEngineFallbackDecisionCode code;
  final AiroPlaybackState state;
  final AiroPlaybackBackendKind engineKind;

  @override
  List<Object?> get props => [code, state, engineKind];
}

/// One-shot **engine-axis** fallback: mirrors the anti-loop shape of
/// `AiroMultiSourceFailoverController` but on the engine axis instead of the
/// source axis. Hard cap of one engine switch per session; once `open()`
/// succeeds, the engine is locked and never swaps again — even if a later
/// runtime error looks like a codec failure.
class AiroEngineFallbackCoordinator {
  AiroEngineFallbackCoordinator({
    required AiroPlaybackEngine primaryEngine,
    this.fallbackEngine,
  }) : _activeEngine = primaryEngine;

  static const Set<AiroPlaybackErrorCode> _engineAxisCodes = {
    AiroPlaybackErrorCode.codecUnsupported,
    AiroPlaybackErrorCode.decoderFailed,
  };

  static const Set<AiroPlaybackErrorCode> _sourceAxisCodes = {
    AiroPlaybackErrorCode.sourceUnavailable,
    AiroPlaybackErrorCode.networkUnavailable,
  };

  final AiroPlaybackEngine? fallbackEngine;
  final Set<AiroPlaybackBackendKind> triedEngines = {};
  final StreamController<AiroEngineFallbackDecision> _runtimeDecisionsController =
      StreamController<AiroEngineFallbackDecision>.broadcast();

  AiroPlaybackEngine _activeEngine;
  StreamSubscription<AiroPlaybackState>? _runtimeSubscription;
  bool _locked = false;
  bool _exhausted = false;

  AiroPlaybackEngine get activeEngine => _activeEngine;
  bool get isLocked => _locked;

  /// Decisions produced from runtime errors observed via the locked engine's
  /// `states` stream (see [_lockOnto]) — always `ignoredLocked`, since a
  /// locked session never swaps. Exposed so callers/UI can react (e.g. show
  /// an error) without re-deriving this from the raw engine stream.
  Stream<AiroEngineFallbackDecision> get runtimeDecisions =>
      _runtimeDecisionsController.stream;

  Future<AiroEngineFallbackDecision> open(AiroMediaOpenRequest request) async {
    if (_locked) {
      final state = await _activeEngine.open(request);
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.ignoredLocked,
        state: state,
        engineKind: _activeEngine.backendKind,
      );
    }

    if (_exhausted) {
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.exhausted,
        state: _activeEngine.currentState,
        engineKind: _activeEngine.backendKind,
      );
    }

    triedEngines.add(_activeEngine.backendKind);
    final state = await _activeEngine.open(request);

    final errorCode = state.error?.code;
    if (errorCode == null) {
      _lockOnto(_activeEngine);
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.openedOnPrimary,
        state: state,
        engineKind: _activeEngine.backendKind,
      );
    }

    if (_sourceAxisCodes.contains(errorCode)) {
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.delegatedToSourceFailover,
        state: state,
        engineKind: _activeEngine.backendKind,
      );
    }

    if (!_engineAxisCodes.contains(errorCode)) {
      _exhausted = true;
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.exhausted,
        state: state,
        engineKind: _activeEngine.backendKind,
      );
    }

    final fallback = fallbackEngine;
    if (fallback == null || triedEngines.contains(fallback.backendKind)) {
      _exhausted = true;
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.exhausted,
        state: state,
        engineKind: _activeEngine.backendKind,
      );
    }

    // Dispose the abandoned primary before constructing/opening the fallback
    // so the two engines are never alive simultaneously on a RAM-constrained
    // device (both native players hold decoder/buffer resources).
    await _activeEngine.dispose();
    triedEngines.add(fallback.backendKind);
    _activeEngine = fallback;
    final fallbackState = await fallback.open(request);

    if (fallbackState.error == null) {
      _lockOnto(fallback);
      return AiroEngineFallbackDecision(
        code: AiroEngineFallbackDecisionCode.switchedToFallback,
        state: fallbackState,
        engineKind: fallback.backendKind,
      );
    }

    _exhausted = true;
    return AiroEngineFallbackDecision(
      code: AiroEngineFallbackDecisionCode.exhausted,
      state: fallbackState,
      engineKind: fallback.backendKind,
    );
  }

  /// Records an error observed after the engine is already locked (e.g. a
  /// mid-playback decode failure surfaced via the engine's `states` stream).
  /// Never swaps engines once locked — invariant #2 in the design spec.
  AiroEngineFallbackDecision recordRuntimeError(AiroPlaybackErrorCode code) {
    return AiroEngineFallbackDecision(
      code: AiroEngineFallbackDecisionCode.ignoredLocked,
      state: _activeEngine.currentState,
      engineKind: _activeEngine.backendKind,
    );
  }

  /// Locks onto [engine] as the permanent engine for this session and
  /// subscribes to its `states` stream so a later runtime codec/decoder
  /// error is observed and routed through [recordRuntimeError] automatically
  /// — never left for a caller to remember to wire up.
  void _lockOnto(AiroPlaybackEngine engine) {
    _locked = true;
    _runtimeSubscription?.cancel();
    _runtimeSubscription = engine.states.listen((state) {
      final code = state.error?.code;
      if (code != null && _engineAxisCodes.contains(code)) {
        _runtimeDecisionsController.add(recordRuntimeError(code));
      }
    });
  }

  /// Disposes the currently active engine and releases coordinator
  /// resources. The coordinator owns `_activeEngine` once locked, so it is
  /// responsible for tearing it down.
  Future<void> dispose() async {
    await _runtimeSubscription?.cancel();
    await _activeEngine.dispose();
    await _runtimeDecisionsController.close();
  }
}
