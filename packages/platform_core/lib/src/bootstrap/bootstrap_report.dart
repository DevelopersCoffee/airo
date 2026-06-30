import 'bootstrap_metrics.dart';

class BootstrapReport {
  final BootstrapMetrics metrics;
  final bool isSuccess;
  final String? fatalError;

  const BootstrapReport({
    required this.metrics,
    required this.isSuccess,
    this.fatalError,
  });
}
