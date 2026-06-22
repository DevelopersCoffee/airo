class TranscriptChunk {
  const TranscriptChunk({
    required this.id,
    required this.meetingId,
    required this.text,
    required this.start,
    required this.end,
    required this.isFinal,
    this.speakerLabel,
    this.confidence = 1,
  });

  final String id;
  final String meetingId;
  final String text;
  final Duration start;
  final Duration end;
  final bool isFinal;
  final String? speakerLabel;
  final double confidence;

  TranscriptChunk copyWith({
    String? id,
    String? meetingId,
    String? text,
    Duration? start,
    Duration? end,
    bool? isFinal,
    String? speakerLabel,
    double? confidence,
  }) {
    return TranscriptChunk(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      text: text ?? this.text,
      start: start ?? this.start,
      end: end ?? this.end,
      isFinal: isFinal ?? this.isFinal,
      speakerLabel: speakerLabel ?? this.speakerLabel,
      confidence: confidence ?? this.confidence,
    );
  }
}
