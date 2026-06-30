class EngineCapabilities {

  const EngineCapabilities({
    this.supportedModalities = const [],
    this.supportedRuntimes = const [],
    this.supportedQuantizations = const [],
    this.supportedPrecisions = const [],
    this.supportedAccelerators = const [],
  });
  final List<String> supportedModalities;
  final List<String> supportedRuntimes;
  final List<String> supportedQuantizations;
  final List<String> supportedPrecisions;
  final List<String> supportedAccelerators;
}
