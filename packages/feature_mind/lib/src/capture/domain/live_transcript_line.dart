/// One rendered row in the live transcript surface.
class LiveTranscriptLine {
  const LiveTranscriptLine({
    required this.segmentId,
    required this.speakerLabel,
    required this.text,
    required this.startMs,
    required this.isPartial,
  });

  final String segmentId;
  final String speakerLabel;
  final String text;
  final int startMs;
  final bool isPartial;
}
