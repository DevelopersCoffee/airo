import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'transcript_quality_evaluator.dart';

/// Persists [MeetingTranscriptQualityReport] beside `transcript.json`.
class MeetingQualityStore {
  MeetingQualityStore({required String storePath}) : _storePath = storePath;

  final String _storePath;

  String qualityPath(String meetingId) {
    final parent = p.dirname(_storePath);
    return p.join(parent, 'transcripts', '$meetingId.quality.json');
  }

  Future<MeetingTranscriptQualityReport?> read(String meetingId) async {
    final file = File(qualityPath(meetingId));
    if (!file.existsSync()) return null;
    try {
      final raw = await file.readAsString();
      final json = jsonDecode(raw) as Map<String, Object?>;
      return MeetingTranscriptQualityReport.fromJson(json);
    } on Object {
      return null;
    }
  }

  Future<void> write(
    String meetingId,
    MeetingTranscriptQualityReport report,
  ) async {
    final file = File(qualityPath(meetingId));
    await file.parent.create(recursive: true);
    final encoded = const JsonEncoder.withIndent('  ').convert(report.toJson());
    await file.writeAsString('$encoded\n');
  }
}
