class CPUCapability {

  const CPUCapability({
    required this.supported,
    this.supportedPrecisions = const [],
    this.maxThreads = 1,
  });
  final bool supported;
  final List<String> supportedPrecisions;
  final int maxThreads;
}

class GPUCapability { // e.g., Metal, Vulkan

  const GPUCapability({
    required this.supported,
    this.supportedPrecisions = const [],
    this.backend = 'unknown',
  });
  final bool supported;
  final List<String> supportedPrecisions;
  final String backend;
}

class NPUCapability { // e.g., CoreML, NNAPI

  const NPUCapability({
    required this.supported,
    this.backend = 'unknown',
  });
  final bool supported;
  final String backend;
}
