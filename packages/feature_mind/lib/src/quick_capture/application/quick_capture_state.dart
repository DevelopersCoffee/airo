import 'package:flutter/foundation.dart';

/// Where a capture is in its life, thumb down to filed.
///
/// [filing] is its own phase rather than folded into [transcribed] because
/// the append is the one step that can fail on a missing [OperationLogPort]
/// -- the surface needs a state that means "committing, and here is the op
/// number it will land on" distinct from "ready to commit".
enum QuickCapturePhase { idle, capturing, transcribed, filing, filed, error }

/// State for one capture, thumb down to filed.
///
/// Surface 07's rule: capture never blocks on classification. The context
/// guess is carried as a *suggestion* ([suggestedContextId]) that arrives on
/// its own schedule -- [QuickCaptureController] never awaits it before
/// moving through [QuickCapturePhase.capturing], [QuickCapturePhase.transcribed]
/// or [QuickCapturePhase.filing]. A person can [QuickCaptureController.overrideContext]
/// at any time; [effectiveContextId] prefers that choice.
@immutable
class QuickCaptureState {
  const QuickCaptureState({
    this.phase = QuickCapturePhase.idle,
    this.transcript = '',
    this.suggestedContextId,
    this.overriddenContextId,
    this.isClassifying = false,
    this.provisionalSequence,
    this.filedSequence,
    this.missingPort,
    this.errorMessage,
  });

  final QuickCapturePhase phase;

  /// Lands before release: updated live while [phase] is
  /// [QuickCapturePhase.capturing], final the moment the thumb lifts.
  final String transcript;

  /// The model's guess at which context this belongs to. Null until the
  /// guess resolves, and it is allowed to still be null when the capture is
  /// committed -- classification is a suggestion, never a gate.
  final String? suggestedContextId;

  /// A person's explicit choice, overriding [suggestedContextId].
  final String? overriddenContextId;

  /// True while the context guess is in flight. Never rendered as a bare
  /// spinner -- a surface either has nothing to show yet or shows the count
  /// backing this flag, per "no spinner without a number".
  final bool isClassifying;

  /// The op number this capture will land on, known before the append
  /// completes (a cheap `count()` ahead of the write). Lets [filing] render
  /// "filing as op #N" instead of an indeterminate spinner.
  final int? provisionalSequence;

  /// The op number this capture landed on, once [phase] is
  /// [QuickCapturePhase.filed].
  final int? filedSequence;

  /// Which sub-port was missing when [phase] became [QuickCapturePhase.error].
  /// Names the port rather than the product, matching [MindPortUnavailable].
  final String? missingPort;
  final String? errorMessage;

  /// The context to file against right now: a person's override first, the
  /// model's guess otherwise, and null when neither exists yet -- filing
  /// against no context at all is allowed rather than blocking.
  String? get effectiveContextId => overriddenContextId ?? suggestedContextId;

  QuickCaptureState copyWith({
    QuickCapturePhase? phase,
    String? transcript,
    String? suggestedContextId,
    String? overriddenContextId,
    bool? isClassifying,
    int? provisionalSequence,
    int? filedSequence,
    String? missingPort,
    String? errorMessage,
  }) => QuickCaptureState(
    phase: phase ?? this.phase,
    transcript: transcript ?? this.transcript,
    suggestedContextId: suggestedContextId ?? this.suggestedContextId,
    overriddenContextId: overriddenContextId ?? this.overriddenContextId,
    isClassifying: isClassifying ?? this.isClassifying,
    provisionalSequence: provisionalSequence ?? this.provisionalSequence,
    filedSequence: filedSequence ?? this.filedSequence,
    missingPort: missingPort ?? this.missingPort,
    errorMessage: errorMessage ?? this.errorMessage,
  );
}
