import 'dart:convert';

import 'research_http.dart';
import 'research_search.dart';

/// Academic paper search. Hits are candidates, not evidence.
class SemanticScholarSearchEngine implements ResearchSearchEngine {
  SemanticScholarSearchEngine({this.http = const ResearchHttpClient()});

  final ResearchHttpClient http;

  @override
  String get id => 'semantic_scholar';

  static List<ResearchHit> parseSearchJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final data = decoded['data'];
    if (data is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final row in data) {
      if (row is! Map) {
        continue;
      }
      final title = '${row['title'] ?? ''}'.trim();
      if (title.isEmpty) {
        continue;
      }
      final abstract = '${row['abstract'] ?? ''}'.trim();
      hits.add(
        ResearchHit(
          engineId: 'semantic_scholar',
          url: _paperUrl(row),
          title: title,
          snippet: abstract,
        ),
      );
    }
    return hits;
  }

  static String _paperUrl(Map<dynamic, dynamic> row) {
    final ids = row['externalIds'];
    if (ids is Map) {
      final arxiv = '${ids['ArXiv'] ?? ''}'.trim();
      if (arxiv.isNotEmpty) {
        return 'https://arxiv.org/abs/$arxiv';
      }
    }
    final url = '${row['url'] ?? ''}'.trim();
    if (url.startsWith('https://')) {
      return url;
    }
    final paperId = '${row['paperId'] ?? ''}'.trim();
    return 'https://www.semanticscholar.org/paper/$paperId';
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('api.semanticscholar.org', '/graph/v1/paper/search', {
      'query': query,
      'limit': '$maxResults',
      'fields': 'title,abstract,url,externalIds',
    });
    final body = await http.get(uri);
    return parseSearchJson(body);
  }
}
