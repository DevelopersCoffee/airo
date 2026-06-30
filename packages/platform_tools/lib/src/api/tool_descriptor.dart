class ToolDescription {
  final String purpose;
  final Map<String, dynamic> parameters;
  final List<String> examples;
  final List<String> sideEffects;
  final List<String> permissions;
  final String estimatedCost;
  final String latencyHints;
  final List<String> capabilities;

  const ToolDescription({
    required this.purpose,
    this.parameters = const {},
    this.examples = const [],
    this.sideEffects = const [],
    this.permissions = const [],
    this.estimatedCost = 'unknown',
    this.latencyHints = 'unknown',
    this.capabilities = const [],
  });
}

abstract interface class ToolDescriptorProvider {
  ToolDescription describe();
}
