import '../bootstrap/bootstrap_context.dart';
import '../bootstrap/bootstrap_phase.dart';
import '../bootstrap/bootstrap_result.dart';

abstract interface class BootstrapTask {
  String get name;
  BootstrapPhase get phase;
  Future<BootstrapResult> execute(BootstrapContext context);
}
