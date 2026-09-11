import 'package:feature_anya_core/feature_anya_core.dart';

/// Session-facing status for optional on-device plan repair.
enum RepairStatus { idle, cleaning, complete, failed }

/// Optional second pass after heuristic import repair.
///
/// Tokens are JSON of a [DietProgram]. Callers must buffer the full stream
/// and validate before swapping [AnyaSessionState.pendingProgram].
abstract class PlanRepairPort {
  bool get isAvailable;

  Stream<String> repair(DietProgram draft);
}

class NoopPlanRepairPort implements PlanRepairPort {
  const NoopPlanRepairPort();

  @override
  bool get isAvailable => false;

  @override
  Stream<String> repair(DietProgram draft) => const Stream.empty();
}
