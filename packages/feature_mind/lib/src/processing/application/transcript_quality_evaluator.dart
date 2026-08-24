import 'package:flutter/foundation.dart';

import '../../bridges/mind_speech_bridge.dart';

/// Per-segment quality finding from [TranscriptQualityEvaluator].
@immutable
class SegmentQualityIssue {
  const SegmentQualityIssue({
    required this.segmentId,
    required this.startMs,
    required this.endMs,
    required this.text,
    required this.signals,
  });

  final String segmentId;
  final int startMs;
  final int endMs;
  final String text;
  final List<String> signals;

  bool get isSuspicious => signals.isNotEmpty;
}

/// Persisted quality metadata for a meeting transcript.
@immutable
class MeetingTranscriptQualityReport {
  const MeetingTranscriptQualityReport({
    required this.overall,
    required this.signals,
    required this.unknownWordRatio,
    required this.retryCount,
    required this.retriedSegmentIds,
    required this.segmentIssues,
    required this.updatedAtMs,
  });

  final TranscriptQualityLevel overall;
  final List<String> signals;
  final double unknownWordRatio;
  final int retryCount;
  final List<String> retriedSegmentIds;
  final List<SegmentQualityIssue> segmentIssues;
  final int updatedAtMs;

  bool get needsReview => overall == TranscriptQualityLevel.suspicious;

  String get headline => needsReview
      ? 'Transcript needs review'
      : 'High-quality transcript generated';

  String get summary {
    if (!needsReview) return headline;
    final parts = <String>[headline];
    if (retryCount > 0) {
      parts.add(
        'Airo retried $retryCount segment${retryCount == 1 ? '' : 's'}.',
      );
    }
    if (signals.isNotEmpty) {
      parts.add(signals.take(3).join(', '));
    }
    return parts.join(' ');
  }

  Map<String, Object?> toJson() => {
    'overall': overall.name,
    'signals': signals,
    'unknownWordRatio': unknownWordRatio,
    'retryCount': retryCount,
    'retriedSegmentIds': retriedSegmentIds,
    'segmentIssues': [
      for (final issue in segmentIssues)
        {
          'segmentId': issue.segmentId,
          'startMs': issue.startMs,
          'endMs': issue.endMs,
          'text': issue.text,
          'signals': issue.signals,
        },
    ],
    'updatedAtMs': updatedAtMs,
  };

  factory MeetingTranscriptQualityReport.fromJson(Map<String, Object?> json) {
    final overallName = json['overall'] as String? ?? 'good';
    return MeetingTranscriptQualityReport(
      overall: TranscriptQualityLevel.values.firstWhere(
        (level) => level.name == overallName,
        orElse: () => TranscriptQualityLevel.good,
      ),
      signals: [
        for (final item in (json['signals'] as List<Object?>? ?? const []))
          '$item',
      ],
      unknownWordRatio: (json['unknownWordRatio'] as num?)?.toDouble() ?? 0,
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
      retriedSegmentIds: [
        for (final item
            in (json['retriedSegmentIds'] as List<Object?>? ?? const []))
          '$item',
      ],
      segmentIssues: [
        for (final raw
            in (json['segmentIssues'] as List<Object?>? ?? const []))
          if (raw is Map)
            SegmentQualityIssue(
              segmentId: '${raw['segmentId']}',
              startMs: (raw['startMs'] as num?)?.toInt() ?? 0,
              endMs: (raw['endMs'] as num?)?.toInt() ?? 0,
              text: '${raw['text']}',
              signals: [
                for (final signal in (raw['signals'] as List<Object?>? ?? const []))
                  '$signal',
              ],
            ),
      ],
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

enum TranscriptQualityLevel { good, suspicious }

/// Heuristic quality signals for suspicious STT output (#1774 follow-on).
@immutable
class TranscriptQualityReport {
  const TranscriptQualityReport({
    required this.overall,
    required this.signals,
    required this.unknownWordRatio,
    required this.retryRecommended,
    this.segmentIssues = const [],
  });

  final TranscriptQualityLevel overall;
  final List<String> signals;
  final double unknownWordRatio;
  final bool retryRecommended;
  final List<SegmentQualityIssue> segmentIssues;

  bool get isSuspicious => overall == TranscriptQualityLevel.suspicious;

  MeetingTranscriptQualityReport toMeetingReport({
    required int retryCount,
    required List<String> retriedSegmentIds,
  }) {
    return MeetingTranscriptQualityReport(
      overall: overall,
      signals: signals,
      unknownWordRatio: unknownWordRatio,
      retryCount: retryCount,
      retriedSegmentIds: retriedSegmentIds,
      segmentIssues: segmentIssues,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

class TranscriptQualityEvaluator {
  const TranscriptQualityEvaluator();

  TranscriptQualityReport evaluate(String transcript) {
    final segmentIssues = <SegmentQualityIssue>[];
    final text = transcript.trim();
    if (text.isEmpty) {
      return const TranscriptQualityReport(
        overall: TranscriptQualityLevel.suspicious,
        signals: ['empty transcript'],
        unknownWordRatio: 1,
        retryRecommended: true,
      );
    }

    final tokens = text.split(RegExp(r'\s+'));
    final signals = <String>[];
    var suspiciousTokens = 0;

    for (final token in tokens) {
      final cleaned = token.replaceAll(RegExp(r'[^\w\-]'), '');
      if (cleaned.isEmpty) continue;
      if (cleaned.length >= 18) {
        suspiciousTokens++;
        if (!signals.contains('abnormally long words')) {
          signals.add('abnormally long words');
        }
      }
      if (_looksLikeGarbage(cleaned)) {
        suspiciousTokens++;
        if (!signals.contains('low-confidence word shapes')) {
          signals.add('low-confidence word shapes');
        }
      }
    }

    final ratio = tokens.isEmpty ? 0.0 : suspiciousTokens / tokens.length;
    if (ratio > 0.08) {
      signals.add('high unknown-word ratio');
    }

    final repeated = _repeatedTokenRatio(tokens);
    if (repeated > 0.35) {
      signals.add('repeated tokens');
    }

    final suspicious = signals.isNotEmpty || ratio > 0.08;
    return TranscriptQualityReport(
      overall: suspicious
          ? TranscriptQualityLevel.suspicious
          : TranscriptQualityLevel.good,
      signals: signals,
      unknownWordRatio: ratio,
      retryRecommended: suspicious && ratio > 0.05,
      segmentIssues: segmentIssues,
    );
  }

  TranscriptQualityReport evaluateSegments(List<TranscriptSegment> segments) {
    if (segments.isEmpty) {
      return evaluate('');
    }

    final issues = <SegmentQualityIssue>[];
    final aggregateSignals = <String>{};
    var suspiciousSegments = 0;

    for (final segment in segments) {
      final report = evaluate(segment.text);
      if (!report.isSuspicious) continue;
      suspiciousSegments++;
      aggregateSignals.addAll(report.signals);
      issues.add(
        SegmentQualityIssue(
          segmentId: segment.id,
          startMs: segment.startMs,
          endMs: segment.endMs,
          text: segment.text,
          signals: report.signals,
        ),
      );
    }

    final ratio = segments.isEmpty ? 0.0 : suspiciousSegments / segments.length;
    final suspicious = issues.isNotEmpty || ratio > 0.12;
    if (ratio > 0.12 && !aggregateSignals.contains('many low-quality segments')) {
      aggregateSignals.add('many low-quality segments');
    }

    return TranscriptQualityReport(
      overall: suspicious
          ? TranscriptQualityLevel.suspicious
          : TranscriptQualityLevel.good,
      signals: aggregateSignals.toList(growable: false),
      unknownWordRatio: ratio,
      retryRecommended: issues.isNotEmpty,
      segmentIssues: issues,
    );
  }

  bool isBetter(String previous, String candidate) {
    final before = evaluate(previous);
    final after = evaluate(candidate);
    if (!before.isSuspicious && after.isSuspicious) return false;
    if (before.isSuspicious && !after.isSuspicious) return true;
    return after.unknownWordRatio < before.unknownWordRatio;
  }

  bool _looksLikeGarbage(String word) {
    if (word.length < 6) return false;
    final vowels = RegExp(r'[aeiouAEIOU]').allMatches(word).length;
    final consonantRun = RegExp(
      r'[bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ]{5,}',
    );
    if (vowels == 0) return true;
    if (consonantRun.hasMatch(word)) return true;
    final upperMid = word.substring(1, word.length - 1);
    if (upperMid == upperMid.toUpperCase() && upperMid.length >= 4) {
      return true;
    }
    return false;
  }

  double _repeatedTokenRatio(List<String> tokens) {
    if (tokens.length < 4) return 0;
    final counts = <String, int>{};
    for (final t in tokens) {
      final key = t.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    return maxCount / tokens.length;
  }
}
