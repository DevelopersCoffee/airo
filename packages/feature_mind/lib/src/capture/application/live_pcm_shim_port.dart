/// PCM ingest for live STT. Desktop uses one `startStream` into native
/// `CaptureFanout` (file + ring). Not a second `AudioRecorder` beside a
/// file encoder — `FanoutBackedAudioRecorderPort` owns the controller
/// lifecycle while this port owns the single microphone stream.
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
