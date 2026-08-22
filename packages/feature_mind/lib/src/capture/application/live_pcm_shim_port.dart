/// PCM fan-out shim for live STT — interim desktop until native capture lands.
abstract interface class LivePcmShimPort {
  /// Normalized RMS (0–1) for the live amplitude meter — not speaker identity.
  void Function(double normalizedRms)? onAmplitude;

  Future<void> start({required String sessionId});

  /// Stops ingesting PCM without tearing down the recorder instance.
  Future<void> pause();

  /// Resumes PCM ingestion after [pause].
  Future<void> resume({required String sessionId});

  Future<void> stop();

  Future<void> dispose();
}
