import '../types/delegate_types.dart';

class DelegateDiagnostics {
  final DelegateType activeDelegate;
  final List<String> failures;
  final String fallbackReason;
  final String accelerationMode;
  final double throughput;

  const DelegateDiagnostics({
    required this.activeDelegate,
    this.failures = const [],
    this.fallbackReason = '',
    this.accelerationMode = 'none',
    this.throughput = 0.0,
  });
}
