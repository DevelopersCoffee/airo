/// User-facing transcription quality outcome — not raw model names.
enum ProcessingProfile {
  /// Live / quick notes — lowest latency, provisional quality.
  fast('fast', 'Fast', 'Live and quick notes'),

  /// Good quality with reasonable processing time.
  balanced('balanced', 'Balanced', 'Good quality + reasonable time'),

  /// Best available local processing for the final transcript.
  maximumQuality(
    'quality',
    'Maximum quality',
    'Best available local processing',
  );

  const ProcessingProfile(this.stableId, this.label, this.subtitle);

  final String stableId;
  final String label;
  final String subtitle;

  static ProcessingProfile fromStableId(String? id) {
    return ProcessingProfile.values.firstWhere(
      (profile) => profile.stableId == id,
      orElse: () => ProcessingProfile.balanced,
    );
  }
}

/// Whether the planner optimizes for responsiveness or final accuracy.
enum ProcessingIntent {
  live,
  finalTranscript,
}
