import 'dart:math' as math;

import '../entities/meeting.dart';
import '../entities/meeting_intelligence.dart';
import '../entities/transcript_chunk.dart';

class MeetingIntelligencePipeline {
  const MeetingIntelligencePipeline({this.embeddingDimensions = 32});

  final int embeddingDimensions;

  Future<MeetingIntelligence> process({
    required Meeting meeting,
    required List<TranscriptChunk> chunks,
  }) async {
    final cleanedTranscript = _cleanupTranscript(
      chunks
          .where((chunk) => chunk.isFinal)
          .map((chunk) => chunk.text)
          .join('\n'),
    );
    final lines = cleanedTranscript
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    final decisions = _extractPrefixed(lines, const [
      'decision:',
      'decided:',
      'we decided',
    ]);
    final risks = _extractPrefixed(lines, const [
      'risk:',
      'concern:',
      'blocker:',
    ]);
    final questions = lines
        .where((line) => line.endsWith('?'))
        .toList(growable: false);
    final actionItems = _extractActionItems(meeting.id, lines);
    final nextSteps = <String>[
      ..._extractPrefixed(lines, const [
        'next step:',
        'next:',
        'follow up:',
        'follow-up:',
      ]),
      ...actionItems.map((item) => item.description),
    ];
    final topics = _extractTopics('${meeting.title}\n$cleanedTranscript');
    final tags = topics
        .map((topic) => topic.replaceAll(' ', '-'))
        .toList(growable: false);
    final embedding = MeetingEmbedding(
      meetingId: meeting.id,
      chunkId: chunks.isEmpty ? meeting.id : chunks.last.id,
      vector: _embed('$cleanedTranscript ${topics.join(' ')}'),
      searchableText: '$cleanedTranscript ${topics.join(' ')}'.toLowerCase(),
    );

    return MeetingIntelligence(
      meetingId: meeting.id,
      cleanedTranscript: cleanedTranscript,
      summary: MeetingSummary(
        executiveSummary: _executiveSummary(meeting, cleanedTranscript),
        detailedSummary: cleanedTranscript.isEmpty
            ? 'No transcript was captured.'
            : cleanedTranscript,
        keyDecisions: decisions,
        openQuestions: questions,
        risks: risks,
        nextSteps: nextSteps,
      ),
      actionItems: actionItems,
      followUps: nextSteps,
      topics: topics,
      tags: tags,
      embedding: embedding,
      privacy: const MeetingPrivacySnapshot(
        isOfflineOnly: true,
        audioUploaded: false,
        transcriptUploaded: false,
        redactionVersion: 'local-regex-v1',
      ),
    );
  }

  String _cleanupTranscript(String transcript) {
    final whitespace = transcript
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .join('\n');
    final cards = whitespace.replaceAll(
      RegExp(r'\b(?:\d[ -]*?){13,19}\b'),
      '[card]',
    );
    return cards.replaceAll(RegExp(r'(?:\+?\d[\s-]?){10,14}\d'), '[phone]');
  }

  String _executiveSummary(Meeting meeting, String cleanedTranscript) {
    if (cleanedTranscript.isEmpty) {
      return '${meeting.title}: no final transcript was captured.';
    }
    final firstSentence = cleanedTranscript
        .split(RegExp(r'(?<=[.!?])\s+'))
        .first;
    return '${meeting.title}: $firstSentence';
  }

  List<String> _extractPrefixed(List<String> lines, List<String> prefixes) {
    final output = <String>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final prefix in prefixes) {
        if (lower.startsWith(prefix)) {
          output.add(
            _ensureSentence(
              line.substring(math.min(prefix.length, line.length)).trim(),
            ),
          );
          break;
        }
        if (lower.contains(prefix)) {
          output.add(
            _ensureSentence(
              line.substring(lower.indexOf(prefix) + prefix.length).trim(),
            ),
          );
          break;
        }
      }
    }
    return output;
  }

  String _ensureSentence(String value) {
    if (value.isEmpty || RegExp(r'[.!?]$').hasMatch(value)) return value;
    return '$value.';
  }

  List<MeetingActionItem> _extractActionItems(
    String meetingId,
    List<String> lines,
  ) {
    final actionPrefixes = ['action:', 'action item:', 'todo:'];
    final items = <MeetingActionItem>[];
    for (final line in lines) {
      final lower = line.toLowerCase();
      final prefix = actionPrefixes
          .where(lower.startsWith)
          .cast<String?>()
          .firstOrNull;
      if (prefix == null) continue;
      final raw = line.substring(prefix.length).trim();
      final ownerMatch = RegExp(
        r'^([A-Z][a-zA-Z]+)\s+(?:will|to)\s+(.+)$',
      ).firstMatch(raw);
      items.add(
        MeetingActionItem(
          id: 'action_${items.length + 1}',
          meetingId: meetingId,
          owner: ownerMatch?.group(1),
          description: ownerMatch?.group(2) ?? raw,
          dueDateText: _extractDueText(raw),
        ),
      );
    }
    return items;
  }

  String? _extractDueText(String text) {
    final match = RegExp(
      r'\b(by|before|on)\s+([A-Za-z]+(?:day)?|\d{1,2}/\d{1,2})\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0);
  }

  List<String> _extractTopics(String text) {
    final normalized = text.toLowerCase();
    final candidates = <String>[
      if (normalized.contains('flutter') || normalized.contains('architecture'))
        'flutter architecture',
      if (normalized.contains('authentication') || normalized.contains('auth'))
        'authentication',
      if (normalized.contains('onboarding')) 'onboarding',
      if (normalized.contains('whisper')) 'on-device transcription',
      if (normalized.contains('offline')) 'offline-first',
      if (normalized.contains('battery')) 'battery efficiency',
      if (normalized.contains('storage')) 'local storage',
    ];
    if (candidates.isEmpty) candidates.add('meeting notes');
    return candidates.toSet().toList(growable: false);
  }

  List<double> _embed(String text) {
    final vector = List<double>.filled(embeddingDimensions, 0);
    final words = text
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty);
    for (final word in words) {
      final bucket =
          word.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
          embeddingDimensions;
      vector[bucket] += 1;
    }
    final norm = math.sqrt(
      vector.fold<double>(0, (sum, value) => sum + value * value),
    );
    if (norm == 0) return vector;
    return vector
        .map((value) => double.parse((value / norm).toStringAsFixed(6)))
        .toList(growable: false);
  }
}
