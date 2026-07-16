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

  AiroPlaybackEngine _activeEngine;
  bool _locked = false;
  bool _exhausted = false;

  AiroPlaybackEngine get activeEngine => _activeEngine;
  bool get isLocked => _locked;

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
      _locked = true;
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

    triedEngines.add(fallback.backendKind);
    _activeEngine = fallback;
    final fallbackState = await fallback.open(request);

    if (fallbackState.error == null) {
      _locked = true;
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
}
