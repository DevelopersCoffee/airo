import 'research_http.dart';
import 'research_search.dart';

class ArxivSearchEngine implements ResearchSearchEngine {
  ArxivSearchEngine({this.http = const ResearchHttpClient()});

  final ResearchHttpClient http;

  @override
  String get id => 'arxiv';

  static List<ResearchHit> parseAtom(String body) {
    final hits = <ResearchHit>[];
    final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(body);
    for (final entry in entries) {
      final block = entry.group(1) ?? '';
      final id = _tag(block, 'id');
      final title = _collapseWs(_tag(block, 'title'));
      final summary = _collapseWs(_tag(block, 'summary'));
      if (id.isEmpty || title.isEmpty) {
        continue;
      }
      hits.add(
        ResearchHit(
          engineId: 'arxiv',
          url: _absUrl(id),
          title: title,
          snippet: summary,
        ),
      );
    }
    return hits;
  }

  static String _tag(String block, String name) {
    final match = RegExp('<$name[^>]*>([\\s\\S]*?)</$name>').firstMatch(block);
    return match?.group(1)?.trim() ?? '';
  }

  static String _collapseWs(String value) {
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _absUrl(String id) {
    final match = RegExp(r'arxiv.org/abs/(\d+\.\d+)').firstMatch(id);
    if (match != null) {
      return 'https://arxiv.org/abs/${match.group(1)}';
    }
    return id.replaceFirst('http://', 'https://');
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('export.arxiv.org', '/api/query', {
      'search_query': 'all:"$query"',
      'start': '0',
      'max_results': '$maxResults',
    });
    final body = await http.get(uri);
    return parseAtom(body);
  }
}
