import 'transcript_chunk.dart';

class MeetingSegment {
  const MeetingSegment({
    required this.id,
    required this.meetingId,
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.isFinal,
    this.speakerLabel,
    this.confidence,
  });

  factory MeetingSegment.fromTranscriptChunk(TranscriptChunk chunk) {
    return MeetingSegment(
      id: chunk.id,
      meetingId: chunk.meetingId,
      text: chunk.text,
      startMs: chunk.startMs,
      endMs: chunk.endMs,
      isFinal: chunk.isFinal,
      speakerLabel: chunk.speakerLabel,
      confidence: chunk.confidence,
    );
  }

  final String id;
  final String meetingId;
  final String text;
  final int startMs;
  final int endMs;
  final bool isFinal;
  final String? speakerLabel;
  final double? confidence;

  TranscriptChunk toTranscriptChunk() {
    return TranscriptChunk(
      id: id,
      meetingId: meetingId,
      text: text,
      startMs: startMs,
      endMs: endMs,
      isFinal: isFinal,
      speakerLabel: speakerLabel,
      confidence: confidence,
    );
  }

  MeetingSegment copyWith({
    String? id,
    String? meetingId,
    String? text,
    int? startMs,
    int? endMs,
    bool? isFinal,
    String? speakerLabel,
    double? confidence,
  }) {
    return MeetingSegment(
      id: id ?? this.id,
      meetingId: meetingId ?? this.meetingId,
      text: text ?? this.text,
      startMs: startMs ?? this.startMs,
      endMs: endMs ?? this.endMs,
      isFinal: isFinal ?? this.isFinal,
      speakerLabel: speakerLabel ?? this.speakerLabel,
      confidence: confidence ?? this.confidence,
    );
  }
}
