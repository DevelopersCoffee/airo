import 'dart:convert';

import 'research_http.dart';
import 'research_search.dart';

class WikipediaSearchEngine implements ResearchSearchEngine {
  WikipediaSearchEngine({this.http = const ResearchHttpClient()});

  final ResearchHttpClient http;

  @override
  String get id => 'wikipedia';

  static List<ResearchHit> parseSearchJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final query = decoded['query'];
    if (query is! Map) {
      return const [];
    }
    final search = query['search'];
    if (search is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final row in search) {
      if (row is! Map) {
        continue;
      }
      final title = '${row['title'] ?? ''}'.trim();
      if (title.isEmpty) {
        continue;
      }
      final snippet = _stripHtml('${row['snippet'] ?? ''}');
      hits.add(
        ResearchHit(
          engineId: 'wikipedia',
          url: 'https://en.wikipedia.org/wiki/${title.replaceAll(' ', '_')}',
          title: title,
          snippet: snippet,
        ),
      );
    }
    return hits;
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .trim();
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('en.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'list': 'search',
      'srsearch': query,
      'format': 'json',
      'srlimit': '$maxResults',
    });
    final body = await http.get(uri);
    return parseSearchJson(body);
  }
}
