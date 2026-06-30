class NativeDiagnostics {
  final int totalAllocatedMemoryBytes;
  final Duration initializationTime;
  final int ffiCallCount;

  const NativeDiagnostics({
    this.totalAllocatedMemoryBytes = 0,
    this.initializationTime = Duration.zero,
    this.ffiCallCount = 0,
  });
}
