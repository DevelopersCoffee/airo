import '../domain/meeting_intelligence_contracts.dart';

abstract interface class MeetingSummaryStageProvider {
  MeetingIntelligenceStage get stage;

  MeetingSummaryProjection process(MeetingIntelligenceJobRequest request);
}

class MeetingSummaryProjection {
  MeetingSummaryProjection({
    required this.executiveSummary,
    required this.detailedSummary,
    required List<String> actionItems,
    required List<String> keyDecisions,
    required List<String> risks,
    required List<String> openQuestions,
    required List<String> followUps,
    required List<String> blockers,
    required List<String> dependencies,
    required List<String> nextSteps,
  }) : actionItems = List.unmodifiable(actionItems),
       keyDecisions = List.unmodifiable(keyDecisions),
       risks = List.unmodifiable(risks),
       openQuestions = List.unmodifiable(openQuestions),
       followUps = List.unmodifiable(followUps),
       blockers = List.unmodifiable(blockers),
       dependencies = List.unmodifiable(dependencies),
       nextSteps = List.unmodifiable(nextSteps);

  final String executiveSummary;
  final String detailedSummary;
  final List<String> actionItems;
  final List<String> keyDecisions;
  final List<String> risks;
  final List<String> openQuestions;
  final List<String> followUps;
  final List<String> blockers;
  final List<String> dependencies;
  final List<String> nextSteps;
}

class DeterministicMeetingSummaryProvider
    implements MeetingSummaryStageProvider {
  const DeterministicMeetingSummaryProvider();

  @override
  MeetingIntelligenceStage get stage => MeetingIntelligenceStage.summary;

  @override
  MeetingSummaryProjection process(MeetingIntelligenceJobRequest request) {
    final searchableText = request.redactedTranscriptSegments.join('\n');
    return MeetingSummaryProjection(
      executiveSummary: _buildExecutiveSummary(searchableText),
      detailedSummary: searchableText,
      actionItems: _extractPrefixedLines(searchableText, 'action:'),
      keyDecisions: _extractPrefixedLines(searchableText, 'decision:'),
      risks: _extractRiskLines(searchableText),
      openQuestions: _extractAnyPrefixedLines(searchableText, const [
        'open question:',
        'question:',
      ]),
      followUps: _extractAnyPrefixedLines(searchableText, const [
        'follow-up:',
        'followup:',
      ]),
      blockers: _extractAnyPrefixedLines(searchableText, const [
        'blocker:',
        'blocked by:',
      ]),
      dependencies: _extractAnyPrefixedLines(searchableText, const [
        'dependency:',
        'depends on:',
      ]),
      nextSteps: _extractPrefixedLines(searchableText, 'next:'),
    );
  }

  String _buildExecutiveSummary(String searchableText) {
    final normalized = searchableText.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return 'No final transcript was captured.';
    }
    return normalized.length <= 240
        ? normalized
        : '${normalized.substring(0, 237)}...';
  }

  List<String> _extractRiskLines(String text) {
    return text
        .split(RegExp(r'[\n.]'))
        .map((line) => line.trim())
        .where((line) => line.toLowerCase().contains('risk'))
        .toList(growable: false);
  }

  List<String> _extractPrefixedLines(String text, String prefix) {
    return _extractAnyPrefixedLines(text, [prefix]);
  }

  List<String> _extractAnyPrefixedLines(String text, List<String> prefixes) {
    return text
        .split(RegExp(r'[\n.]'))
        .map((line) => line.trim())
        .map((line) {
          final normalized = line.toLowerCase();
          for (final prefix in prefixes) {
            if (normalized.startsWith(prefix)) {
              return line.substring(prefix.length).trim();
            }
          }
          return null;
        })
        .whereType<String>()
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}
