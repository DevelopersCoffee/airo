enum MeetingState { recording, completed, cancelled, failed }

class MeetingRecord {
  const MeetingRecord({
    required this.id,
    required this.title,
    required this.startedAt,
    required this.state,
    this.endedAt,
    this.languageCode,
  });

  factory MeetingRecord.started({
    required String id,
    required String title,
    required DateTime startedAt,
    String? languageCode,
  }) {
    return MeetingRecord(
      id: id,
      title: title,
      startedAt: startedAt,
      state: MeetingState.recording,
      languageCode: languageCode,
    );
  }

  final String id;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final MeetingState state;
  final String? languageCode;

  MeetingRecord complete({required DateTime endedAt}) {
    return copyWith(endedAt: endedAt, state: MeetingState.completed);
  }

  MeetingRecord copyWith({
    String? id,
    String? title,
    DateTime? startedAt,
    DateTime? endedAt,
    MeetingState? state,
    String? languageCode,
  }) {
    return MeetingRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      state: state ?? this.state,
      languageCode: languageCode ?? this.languageCode,
    );
  }
}
