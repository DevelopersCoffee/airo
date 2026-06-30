class EngineDescriptor {

  const EngineDescriptor({
    required this.identifier,
    required this.version,
    required this.vendor,
    this.supportedPlatforms = const [],
    this.supportedQuantizations = const [],
    this.supportedModalities = const [],
    this.supportedPrecisions = const [],
    this.supportsStreaming = false,
    this.supportsBatching = false,
    this.supportsToolCalling = false,
    this.supportsSpeculativeDecoding = false,
  });
  final String identifier;
  final String version;
  final String vendor;
  final List<String> supportedPlatforms;
  final List<String> supportedQuantizations;
  final List<String> supportedModalities;
  final List<String> supportedPrecisions;
  final bool supportsStreaming;
  final bool supportsBatching;
  final bool supportsToolCalling;
  final bool supportsSpeculativeDecoding;
}
