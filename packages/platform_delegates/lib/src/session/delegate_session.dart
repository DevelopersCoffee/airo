import '../types/delegate_types.dart';

class DelegateSelection {

  const DelegateSelection({
    required this.selectedDelegate,
    required this.fallbackChain,
    required this.confidence,
    required this.explanation,
  });
  final DelegateType selectedDelegate;
  final List<DelegateType> fallbackChain;
  final double confidence;
  final String explanation;
}

abstract interface class DelegateSession {
  DelegateSelection get selection;
  Future<void> initialize();
  Future<void> dispose();
}
