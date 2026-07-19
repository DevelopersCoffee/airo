import 'package:equatable/equatable.dart';

/// Stages of the staged playlist import pipeline.
///
/// The pipeline is: Import → Validate → Download → Parse → Normalize →
/// Deduplicate → Index → GenerateRails → Persist → Ready, with a terminal
/// `failed` stage reachable from any point in the sequence. v1 may emit some
/// adjacent stages back-to-back with near-zero duration (e.g. normalize and
/// index) when the current implementation doesn't yet distinguish the work
/// each stage represents, but the enum contract itself is already complete so
/// later work (e.g. background imports, large-playlist chunking) can report
/// against it without a breaking change.
enum ImportStage {
  import_,
  validate,
  download,
  parse,
  normalize,
  deduplicate,
  // Named `indexing`, not `index`: an enum value literally named `index`
  // fails to compile — it collides with the `int get index` position getter
  // every Dart enum inherits from `Enum`.
  indexing,
  generateRails,
  persist,
  ready,
  failed,
}

/// A single progress emission from [ImportStage] pipeline.
///
/// One `ImportProgress` is emitted per stage transition. The terminal
/// emission is either `ImportStage.ready` (with the imported channel count in
/// [message]) or `ImportStage.failed` (with a non-null [error] and no `ready`
/// ever emitted for that run).
class ImportProgress extends Equatable {
  const ImportProgress({
    required this.stage,
    this.fraction = 0.0,
    this.message,
    this.error,
  });

  /// The pipeline stage this emission reports on.
  final ImportStage stage;

  /// Progress within the stage, `0..1`.
  final double fraction;

  /// Human-readable status for the current stage, if any.
  final String? message;

  /// The failure that ended the pipeline, set only when [stage] is
  /// `ImportStage.failed`.
  final Object? error;

  @override
  List<Object?> get props => [stage, fraction, message, error];
}
