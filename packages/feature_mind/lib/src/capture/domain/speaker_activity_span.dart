/// One provisional speaker-activity interval for the live timeline (`P1`).
class SpeakerActivitySpan {
  const SpeakerActivitySpan({
    required this.speakerIndex,
    required this.startMs,
    required this.endMs,
  });

  final int speakerIndex;
  final int startMs;
  final int endMs;
}
