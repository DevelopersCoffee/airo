import '../types/delegate_types.dart';

class DelegateDiagnostics {

  const DelegateDiagnostics({
    required this.activeDelegate,
    this.failures = const [],
    this.fallbackReason = '',
    this.accelerationMode = 'none',
    this.throughput = 0.0,
  });
  final DelegateType activeDelegate;
  final List<String> failures;
  final String fallbackReason;
  final String accelerationMode;
  final double throughput;
}
