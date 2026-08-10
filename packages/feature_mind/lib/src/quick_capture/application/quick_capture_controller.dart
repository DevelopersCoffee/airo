import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';

import '../../runtime/mind_runtime.dart';
import '../../runtime/models/log_models.dart';
import '../../runtime/ports/context_port.dart';
import '../../runtime/ports/operation_log_port.dart';
import 'quick_capture_state.dart';

/// Surface 07: one thumb, one second.
///
/// Binds to [OperationLogPort] and [ContextPort] only -- the [ModelPort]
/// dependency the design lists is the menu bar's "running model, tok/s"
/// readout (surface 12), which this phone controller does not render. Every
/// method here either completes fast or never blocks the ones that follow
/// it: [startCapture] fires the context guess without awaiting it, and
/// [releaseCapture] finalises the transcript without touching that guess at
/// all. A capture can reach [QuickCapturePhase.filed] having never learned
/// what context it belongs to.
class QuickCaptureController extends ChangeNotifier {
  QuickCaptureController({required this.log, required this.contexts});

  final OperationLogPort log;
  final ContextPort contexts;

  QuickCaptureState _state = const QuickCaptureState();
  QuickCaptureState get state => _state;

  void _emit(QuickCaptureState next) {
    _state = next;
    notifyListeners();
  }

  /// Thumb goes down. The hold itself is the capture -- nothing here waits
  /// on a port before the surface can start taking speech.
  void startCapture() {
    if (_state.phase != QuickCapturePhase.idle) return;
    _emit(const QuickCaptureState(phase: QuickCapturePhase.capturing));
    // Fire-and-forget: classification is a suggestion, never a gate. Nothing
    // downstream (updateTranscript, releaseCapture, commit) awaits this.
    unawaited(_guessContext());
  }

  /// Transcription lands before release: partial text streams in live while
  /// the thumb is still down.
  void updateTranscript(String text) {
    if (_state.phase != QuickCapturePhase.capturing) return;
    _emit(_state.copyWith(transcript: text));
  }

  /// Thumb lifts. The transcript is already final by the time this is
  /// called, and release does not wait on the context guess even if it is
  /// still in flight -- [QuickCapturePhase.transcribed] is reachable with
  /// [QuickCaptureState.suggestedContextId] still null.
  void releaseCapture() {
    if (_state.phase != QuickCapturePhase.capturing) return;
    _emit(_state.copyWith(phase: QuickCapturePhase.transcribed));
  }

  /// A person's explicit choice. Always wins over the guess, whether it
  /// arrived yet or not.
  void overrideContext(String contextId) {
    _emit(_state.copyWith(overriddenContextId: contextId));
  }

  Future<void> _guessContext() async {
    _emit(_state.copyWith(isClassifying: true));
    try {
      final allContexts = await contexts.all();
      // The capture may already have been committed or abandoned by the time
      // this resolves -- a late guess must not resurrect a finished capture.
      if (_state.phase == QuickCapturePhase.idle ||
          _state.phase == QuickCapturePhase.filed) {
        return;
      }
      if (allContexts.isEmpty) {
        _emit(_state.copyWith(isClassifying: false));
        return;
      }
      final guess = allContexts.reduce(
        (a, b) => a.openedAtMs >= b.openedAtMs ? a : b,
      );
      _emit(
        _state.copyWith(suggestedContextId: guess.id, isClassifying: false),
      );
    } on MindPortUnavailable {
      // A missing context port costs the suggestion, not the capture: the
      // person can still file with no context, or type one in later.
      _emit(_state.copyWith(isClassifying: false));
    }
  }

  /// Commits transcript + context to the log. Fetches the target op number
  /// before appending so [QuickCapturePhase.filing] can render "filing as
  /// op #N" -- no spinner without a number.
  Future<void> commit({required String title}) async {
    if (_state.phase != QuickCapturePhase.transcribed) return;

    final int provisional;
    try {
      provisional = await log.count() + 1;
    } on MindPortUnavailable catch (e) {
      _emit(
        _state.copyWith(
          phase: QuickCapturePhase.error,
          missingPort: e.port,
          errorMessage: e.reason,
        ),
      );
      return;
    }

    _emit(
      _state.copyWith(
        phase: QuickCapturePhase.filing,
        provisionalSequence: provisional,
      ),
    );

    try {
      final sequence = await log.append(
        kind: MindOpKind.voice,
        title: title,
        contextId: _state.effectiveContextId ?? '',
        detail: _state.transcript,
      );
      _emit(
        _state.copyWith(
          phase: QuickCapturePhase.filed,
          filedSequence: sequence,
        ),
      );
    } on MindPortUnavailable catch (e) {
      _emit(
        _state.copyWith(
          phase: QuickCapturePhase.error,
          missingPort: e.port,
          errorMessage: e.reason,
        ),
      );
    }
  }

  /// Clears the surface for the next capture.
  void reset() => _emit(const QuickCaptureState());
}
