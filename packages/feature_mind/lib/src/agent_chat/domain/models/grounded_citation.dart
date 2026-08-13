import 'package:flutter/foundation.dart';

/// Whether an assistant answer is backed by a real logged operation.
///
/// `ungrounded` is not the same as `notApplicable`. A plain navigation
/// action (open a route, acknowledge a cancellation) carries no factual claim
/// to ground. An answer that describes local data without a citation is a
/// different thing entirely: it must say `ungrounded` rather than render
/// silently as if a `GROUNDED IN` block backed it.
enum GroundingState { notApplicable, grounded, ungrounded }

/// Names the op a grounded answer was replayed from.
///
/// [opSequence] is the number the whole product cites — see `MindOp.sequence`
/// in `OperationLogPort`. A citation always carries a sequence a caller can
/// resolve with `OperationLogPort.bySequence`; there is no such thing as a
/// citation to nothing.
@immutable
class GroundedCitation {
  const GroundedCitation({
    required this.opSequence,
    required this.sourceLabel,
    this.contextLabel,
  });

  /// The op number, as recorded by `OperationLogPort`.
  final int opSequence;

  /// What the op was — a `MindOp.title`.
  final String sourceLabel;

  /// The context the op belongs to, when it has one.
  final String? contextLabel;

  @override
  bool operator ==(Object other) =>
      other is GroundedCitation &&
      other.opSequence == opSequence &&
      other.sourceLabel == sourceLabel &&
      other.contextLabel == contextLabel;

  @override
  int get hashCode => Object.hash(opSequence, sourceLabel, contextLabel);
}
