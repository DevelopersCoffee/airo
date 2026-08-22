import '../../models/research_request.dart';

class ResearchHit {
  const ResearchHit({
    required this.engineId,
    required this.url,
    required this.title,
    required this.snippet,
    this.trustLevel = SourceTrust.untrusted,
  });

  final String engineId;
  final String url;
  final String title;
  final String snippet;

  /// Retrieved pages are evidence, never instructions.
  final SourceTrust trustLevel;
}

enum SourceTrust { system, user, untrusted }

abstract class ResearchSearchEngine {
  String get id;

  Future<List<ResearchHit>> search(String query, {int maxResults = 5});
}

/// Policy → engine ids. Google is never implied.
class SearchRouter {
  static List<String> engineIds(SearchPolicy policy) {
    switch (policy) {
      case SearchPolicy.localOnly:
        return const [];
      case SearchPolicy.privacyFirst:
        return const ['wikipedia', 'searxng'];
      case SearchPolicy.balanced:
      case SearchPolicy.maximumQuality:
        return const ['wikipedia', 'arxiv', 'semantic_scholar'];
      case SearchPolicy.academic:
        return const ['arxiv', 'semantic_scholar', 'pubmed'];
    }
  }

  static List<String> engineIdsFor(PrivacyProfile profile) => profile.engineIds;
}
