import 'bootstrap_phase.dart';

class BootstrapResult {
  final bool isSuccess;
  final String? errorMessage;
  final BootstrapPhase phase;

  const BootstrapResult.success(this.phase)
      : isSuccess = true,
        errorMessage = null;

  const BootstrapResult.failure(this.phase, this.errorMessage)
      : isSuccess = false;
}
