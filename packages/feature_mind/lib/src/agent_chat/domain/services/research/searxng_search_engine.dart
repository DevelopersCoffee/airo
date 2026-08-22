import 'dart:convert';

import 'package:core_workers/core_workers.dart';

import 'research_http.dart';
import 'research_search.dart';

/// Search adapter for an explicitly configured self-hosted SearXNG instance.
///
/// SearXNG results are candidates, not evidence. The configured API host is
/// added only to this adapter's HTTP allowlist; there is no default public host.
class SearxngSearchEngine implements ResearchSearchEngine {
  factory SearxngSearchEngine({
    required Uri baseUri,
    ResearchHttpClient? http,
  }) {
    if (baseUri.scheme != 'https' ||
        baseUri.host.isEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment ||
        baseUri.userInfo.isNotEmpty) {
      throw const ResearchHttpException(
        'SearXNG requires an HTTPS base URI without credentials, query, or fragment.',
      );
    }
    final client =
        http ??
        ResearchHttpClient(
          allowedHosts: {
            ...ResearchHttpClient.defaultAllowedHosts,
            baseUri.host,
          },
        );
    client.validate(baseUri);
    return SearxngSearchEngine._(baseUri: baseUri, http: client);
  }

  const SearxngSearchEngine._({required this.baseUri, required this.http});

  static const _offMainThreshold = 50 * 1024;

  final Uri baseUri;
  final ResearchHttpClient http;

  @override
  String get id => 'searxng';

  static List<ResearchHit> parseSearchJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final results = decoded['results'];
    if (results is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final row in results) {
      if (row is! Map) {
        continue;
      }
      final url = Uri.tryParse('${row['url'] ?? ''}'.trim());
      final title = _stripHtml('${row['title'] ?? ''}');
      if (url == null || url.scheme != 'https' || title.isEmpty) {
        continue;
      }
      hits.add(
        ResearchHit(
          engineId: 'searxng',
          url: url.toString(),
          title: title,
          snippet: _stripHtml('${row['content'] ?? ''}'),
          trustLevel: SourceTrust.untrusted,
        ),
      );
    }
    return hits;
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty || maxResults <= 0) {
      return const [];
    }
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final uri = baseUri.replace(
      path: '${basePath}search',
      queryParameters: {'q': query, 'format': 'json', 'categories': 'general'},
    );
    final body = await http.get(uri);
    final hits = body.length > _offMainThreshold
        ? await runOffMain(() => parseSearchJson(body))
        : parseSearchJson(body);
    return hits.take(maxResults).toList(growable: false);
  }

  static String _stripHtml(String raw) {
    return raw
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
