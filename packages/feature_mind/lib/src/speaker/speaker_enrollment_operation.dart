/// Durable speaker enrollment operation kinds (#504).
///
/// Closed set — matches the Notes capability pattern until Rust #1213 owns the
/// log.
enum SpeakerEnrollmentOpKind {
  enroll,
  remove;

  String get wireName => name;

  static SpeakerEnrollmentOpKind fromWireName(String name) =>
      SpeakerEnrollmentOpKind.values.firstWhere(
        (kind) => kind.name == name,
        orElse: () =>
            throw FormatException('unknown speaker enrollment op: $name'),
      );
}

/// One append-only enrollment log entry (#504).
class SpeakerEnrollmentOperation {
  const SpeakerEnrollmentOperation({
    required this.seq,
    required this.kind,
    required this.id,
    required this.displayName,
    required this.recordedAtMs,
  });

  final int seq;
  final SpeakerEnrollmentOpKind kind;
  final String id;
  final String displayName;
  final int recordedAtMs;

  Map<String, Object?> toJson() => {
    'seq': seq,
    'kind': kind.wireName,
    'id': id,
    'displayName': displayName,
    'recordedAtMs': recordedAtMs,
  };

  factory SpeakerEnrollmentOperation.fromJson(Map<String, Object?> json) =>
      SpeakerEnrollmentOperation(
        seq: json['seq'] as int,
        kind: SpeakerEnrollmentOpKind.fromWireName(json['kind'] as String),
        id: json['id'] as String? ?? '',
        displayName: json['displayName'] as String? ?? '',
        recordedAtMs: json['recordedAtMs'] as int? ?? 0,
      );
}
