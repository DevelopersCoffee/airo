import 'dart:convert';
import 'dart:io';

import 'research_http.dart';
import 'research_search.dart';

Future<ResearchHttpTransportResponse> _githubTransport(
  Uri uri,
  Duration timeout,
) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'Airo-Mind-Research/1.0');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final response = await request.close().timeout(timeout);
    return ResearchHttpTransportResponse(
      statusCode: response.statusCode,
      location: response.headers.value(HttpHeaders.locationHeader),
      chunks: response,
      close: () => client.close(force: true),
    );
  } catch (_) {
    client.close(force: true);
    rethrow;
  }
}

/// GitHub repository search. Hits are candidates, not evidence.
class GitHubSearchEngine implements ResearchSearchEngine {
  GitHubSearchEngine({ResearchHttpClient? http})
    : http =
          http ??
          const ResearchHttpClient(
            allowedHosts: {'api.github.com', 'github.com'},
            transport: _githubTransport,
          );

  final ResearchHttpClient http;

  @override
  String get id => 'github';

  static List<ResearchHit> parseSearchJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final items = decoded['items'];
    if (items is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final row in items) {
      if (row is! Map) {
        continue;
      }
      final url = Uri.tryParse('${row['html_url'] ?? ''}'.trim());
      final title = '${row['full_name'] ?? ''}'.trim();
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          title.isEmpty) {
        continue;
      }
      hits.add(
        ResearchHit(
          engineId: 'github',
          url: url.toString(),
          title: title,
          snippet: '${row['description'] ?? ''}'.trim(),
        ),
      );
    }
    return hits;
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('api.github.com', '/search/repositories', {
      'q': query,
      'per_page': '$maxResults',
    });
    final body = await http.get(uri);
    return parseSearchJson(body);
  }
}
