enum TranscriptRedactionStatus { raw, redacted }

class TranscriptChunk {
  const TranscriptChunk({
    required this.id,
    required this.meetingId,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.isFinal,
    this.speakerLabel,
    this.confidence,
    this.redactionStatus = TranscriptRedactionStatus.raw,
  });

  const TranscriptChunk.partial({
    required String id,
    required String meetingId,
    required String text,
    required int startMs,
    required int endMs,
    String? speakerLabel,
    double? confidence,
  }) : this(
         id: id,
         meetingId: meetingId,
         text: text,
         startMs: startMs,
         endMs: endMs,
         isFinal: false,
         speakerLabel: speakerLabel,
         confidence: confidence,
       );

  const TranscriptChunk.finalChunk({
    required String id,
    required String meetingId,
    required String text,
    required int startMs,
    required int endMs,
    String? speakerLabel,
    double? confidence,
  }) : this(
         id: id,
         meetingId: meetingId,
         text: text,
         startMs: startMs,
         endMs: endMs,
         isFinal: true,
         speakerLabel: speakerLabel,
         confidence: confidence,
       );

  final String id;
  final String meetingId;
  final String text;
  final int startMs;
  final int endMs;
  final bool isFinal;
  final String? speakerLabel;
  final double? confidence;
  final TranscriptRedactionStatus redactionStatus;

  TranscriptChunk copyWith({
    String? id,
    String? meetingId,
    String? text,
    int? startMs,
    int? endMs,
    bool? isFinal,
    String? speakerLabel,
    double? confidence,
    TranscriptRedactionStatus? redactionStatus,
  }) {
    return TranscriptChunk(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      isFinal: isFinal ?? this.isFinal,
      speakerLabel: speakerLabel ?? this.speakerLabel,
      confidence: confidence ?? this.confidence,
      redactionStatus: redactionStatus ?? this.redactionStatus,
    );
  }
}
