import '../../models/research_request.dart';

enum ResearchIntent {
  factFinding,
  comparison,
  decisionSupport,
  technicalResearch,
  academicResearch,
  marketResearch,
  productResearch,
  newsResearch,
  investigation,
  deepExploration,
}

class InterpretedGoal {
  const InterpretedGoal({
    required this.topic,
    required this.intent,
    required this.dimensions,
    required this.decisionRequired,
    this.freshnessYear,
  });

  final String topic;
  final ResearchIntent intent;
  final List<String> dimensions;
  final bool decisionRequired;
  final int? freshnessYear;
}

class ResearchInterpreter {
  const ResearchInterpreter();

  InterpretedGoal interpret(ResearchRequest request) {
    final topic = request.question.trim();
    final intent = classify(topic);
    return InterpretedGoal(
      topic: topic,
      intent: intent,
      dimensions: dimensionsFor(intent),
      decisionRequired:
          intent == ResearchIntent.decisionSupport ||
          intent == ResearchIntent.comparison,
      freshnessYear: yearIn(topic),
    );
  }

  static ResearchIntent classify(String question) {
    final q = question.toLowerCase();
    if (q.contains(' vs ') || q.contains('versus') || q.contains('compare ')) {
      return ResearchIntent.comparison;
    }
    if (q.contains('which should') ||
        q.contains('should i') ||
        q.contains('should we') ||
        q.contains('best ') ||
        q.contains('recommend')) {
      return ResearchIntent.decisionSupport;
    }
    if (q.contains('who invented') ||
        q.contains('who created') ||
        q.startsWith('what is ') ||
        q.startsWith('when was ') ||
        q.startsWith('when did ')) {
      return ResearchIntent.factFinding;
    }
    if (q.contains('arxiv') ||
        q.contains('pubmed') ||
        q.contains('peer-reviewed')) {
      return ResearchIntent.academicResearch;
    }
    if (q.contains('market') || q.contains('pricing')) {
      return ResearchIntent.marketResearch;
    }
    if (q.contains('breaking news') || q.contains('headlines')) {
      return ResearchIntent.newsResearch;
    }
    if (q.contains('investigate') || q.contains('what went wrong')) {
      return ResearchIntent.investigation;
    }
    if (q.contains('product') && q.contains('review')) {
      return ResearchIntent.productResearch;
    }
    return ResearchIntent.technicalResearch;
  }

  static List<String> splitSubjects(String question) {
    final lowered = question.toLowerCase();
    var rest = question;
    final compareAt = lowered.indexOf('compare ');
    if (compareAt >= 0) {
      rest = question.substring(compareAt + 'compare '.length);
    }
    final forAt = rest.toLowerCase().indexOf(' for ');
    if (forAt >= 0) {
      rest = rest.substring(0, forAt);
    }
    final vsAt = rest.toLowerCase().indexOf(' vs ');
    if (vsAt >= 0) {
      rest = rest.substring(0, vsAt);
    }
    return rest
        .replaceAll(' versus ', ', ')
        .replaceAll(' and ', ', ')
        .split(',')
        .map((part) => part.trim().replaceAll(RegExp(r'[.?]$'), ''))
        .where((part) => part.length >= 2)
        .toList(growable: false);
  }

  static List<String> dimensionsFor(ResearchIntent intent) {
    switch (intent) {
      case ResearchIntent.decisionSupport:
      case ResearchIntent.comparison:
        return const [
          'quality',
          'latency',
          'memory',
          'licensing',
          'mobile support',
          'offline support',
          'tooling',
        ];
      case ResearchIntent.technicalResearch:
        return const ['architecture', 'constraints', 'implementation'];
      case ResearchIntent.academicResearch:
        return const ['primary literature', 'methods', 'replication'];
      default:
        return const ['primary sources'];
    }
  }

  static int? yearIn(String question) {
    final match = RegExp(r'\b(199\d|20\d{2})\b').firstMatch(question);
    return match == null ? null : int.tryParse(match.group(1)!);
  }
}
