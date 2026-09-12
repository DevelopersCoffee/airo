import 'package:feature_anya/feature_anya.dart';

/// Web / no-`dart:io` Anya shell: Review stays heuristic.
Future<PlanRepairPort> createAnyaPlanRepairPort() async {
  return const NoopPlanRepairPort();
}
