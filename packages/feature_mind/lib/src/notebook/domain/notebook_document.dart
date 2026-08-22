import 'dart:convert';

import 'notebook_source.dart';

/// Structured notebook payload stored in [Note.body].
///
/// The Notes operation log still carries only `id` / `title` / `body`
/// (`#1338`, lockstep with `airo_mind_core::notes`). Product fields — tags,
/// summary, transcript, language — live inside this envelope so the runtime
/// encoding does not change.
///
/// A note that is only a title and freeform body stores plaintext, not JSON,
/// so handwritten notes and the vertical-slice tests stay readable.
class NotebookDocument {
  const NotebookDocument({
    this.body = '',
    this.transcript = '',
    this.summary = '',
    this.keyPoints = const [],
    this.tags = const [],
    this.labels = const [],
    this.languageCode,
    this.source = NotebookSource.manual,
    this.sourceNoteIds = const [],
    this.meetingId,
    this.audioPath,
  });

  static const schemaId = 'airo.mind.notebook.v1';

  /// Freeform notes the person typed, distinct from [transcript].
  final String body;
  final String transcript;
  final String summary;
  final List<String> keyPoints;
  final List<String> tags;
  final List<String> labels;

  /// Whisper / UI language code (`hi`, `en`, …), or `null` for auto / unset.
  final String? languageCode;
  final NotebookSource source;

  /// For [NotebookSource.superSummary], the notes that were folded in.
  final List<String> sourceNoteIds;
  final String? meetingId;
  final String? audioPath;

  bool get isPlain =>
      transcript.isEmpty &&
      summary.isEmpty &&
      keyPoints.isEmpty &&
      tags.isEmpty &&
      labels.isEmpty &&
      languageCode == null &&
      source == NotebookSource.manual &&
      sourceNoteIds.isEmpty &&
      meetingId == null &&
      audioPath == null;

  String get preview {
    if (summary.trim().isNotEmpty) return summary.trim();
    if (body.trim().isNotEmpty) return body.trim();
    if (transcript.trim().isNotEmpty) return transcript.trim();
    if (keyPoints.isNotEmpty) return keyPoints.join(' · ');
    return '';
  }

  NotebookDocument copyWith({
    String? body,
    String? transcript,
    String? summary,
    List<String>? keyPoints,
    List<String>? tags,
    List<String>? labels,
    String? languageCode,
    NotebookSource? source,
    List<String>? sourceNoteIds,
    String? meetingId,
    String? audioPath,
    bool clearLanguageCode = false,
    bool clearMeetingId = false,
    bool clearAudioPath = false,
  }) {
    return NotebookDocument(
      body: body ?? this.body,
      transcript: transcript ?? this.transcript,
      summary: summary ?? this.summary,
      keyPoints: keyPoints ?? this.keyPoints,
      tags: tags ?? this.tags,
      labels: labels ?? this.labels,
      languageCode: clearLanguageCode
          ? null
          : languageCode ?? this.languageCode,
      source: source ?? this.source,
      sourceNoteIds: sourceNoteIds ?? this.sourceNoteIds,
      meetingId: clearMeetingId ? null : meetingId ?? this.meetingId,
      audioPath: clearAudioPath ? null : audioPath ?? this.audioPath,
    );
  }

  /// Encodes for [Note.body]. Plain notes stay plaintext.
  String encode() {
    if (isPlain) return body;
    return jsonEncode(toJson());
  }

  Map<String, Object?> toJson() => {
    'schema': schemaId,
    'body': body,
    'transcript': transcript,
    'summary': summary,
    'keyPoints': keyPoints,
    'tags': tags,
    'labels': labels,
    'languageCode': languageCode,
    'source': source.name,
    'sourceNoteIds': sourceNoteIds,
    'meetingId': meetingId,
    'audioPath': audioPath,
  };

  /// Reads a [Note.body]. Unknown JSON falls back to treating the string as
  /// plaintext so a corrupt envelope never deletes the person's words.
  static NotebookDocument decode(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const NotebookDocument();
    if (!trimmed.startsWith('{')) {
      return NotebookDocument(body: raw);
    }
    try {
      final json = jsonDecode(trimmed);
      if (json is! Map) return NotebookDocument(body: raw);
      final map = Map<String, Object?>.from(json);
      if (map['schema'] != schemaId) return NotebookDocument(body: raw);
      return fromJson(map);
    } on FormatException {
      return NotebookDocument(body: raw);
    }
  }

  static NotebookDocument fromJson(Map<String, Object?> json) {
    return NotebookDocument(
      body: json['body'] as String? ?? '',
      transcript: json['transcript'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      keyPoints: _stringList(json['keyPoints']),
      tags: _stringList(json['tags']),
      labels: _stringList(json['labels']),
      languageCode: json['languageCode'] as String?,
      source: NotebookSource.fromName(json['source'] as String?),
      sourceNoteIds: _stringList(json['sourceNoteIds']),
      meetingId: json['meetingId'] as String?,
      audioPath: json['audioPath'] as String?,
    );
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is NotebookDocument &&
      other.body == body &&
      other.transcript == transcript &&
      other.summary == summary &&
      _listEq(other.keyPoints, keyPoints) &&
      _listEq(other.tags, tags) &&
      _listEq(other.labels, labels) &&
      other.languageCode == languageCode &&
      other.source == source &&
      _listEq(other.sourceNoteIds, sourceNoteIds) &&
      other.meetingId == meetingId &&
      other.audioPath == audioPath;

  @override
  int get hashCode => Object.hash(
    body,
    transcript,
    summary,
    Object.hashAll(keyPoints),
    Object.hashAll(tags),
    Object.hashAll(labels),
    languageCode,
    source,
    Object.hashAll(sourceNoteIds),
    meetingId,
    audioPath,
  );
}

bool _listEq(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
