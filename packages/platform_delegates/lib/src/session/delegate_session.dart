import '../types/delegate_types.dart';

class DelegateSelection {
  final DelegateType selectedDelegate;
  final List<DelegateType> fallbackChain;
  final double confidence;
  final String explanation;

  const DelegateSelection({
    required this.selectedDelegate,
    required this.fallbackChain,
    required this.confidence,
    required this.explanation,
  });
}

abstract interface class DelegateSession {
  DelegateSelection get selection;
  Future<void> initialize();
  Future<void> dispose();
}
