import 'dart:convert';

import 'package:core_workers/core_workers.dart';

import 'research_http.dart';
import 'research_search.dart';

/// Search adapter for an explicitly configured self-hosted SearXNG instance.
///
/// SearXNG results are candidates, not evidence. The configured API host is
/// isolated to this adapter's HTTP origin; there is no default public host.
/// Candidate URLs still pass through the independent source-acquisition
/// allowlist, which this adapter never expands.
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
          allowedHosts: {baseUri.host},
          allowedOrigins: {baseUri.origin},
        );
    if (client.allowedHosts.length != 1 ||
        !client.allowedHosts.contains(baseUri.host) ||
        client.allowedOrigins.length != 1 ||
        !client.allowedOrigins.contains(baseUri.origin)) {
      throw const ResearchHttpException(
        'SearXNG HTTP access must be isolated to its configured origin.',
      );
    }
    client.validate(baseUri);
    return SearxngSearchEngine._(baseUri: baseUri, http: client);
  }

  const SearxngSearchEngine._({required this.baseUri, required this.http});

  // UTF-8 can use up to three bytes per UTF-16 code unit for non-surrogate
  // text. Offloading above 16 Ki code units guarantees any JSON that could
  // exceed ~50 KiB never reaches jsonDecode on the main isolate.
  static const _offMainCodeUnitThreshold = 16 * 1024;

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
      if (url == null ||
          url.scheme != 'https' ||
          url.host.isEmpty ||
          url.userInfo.isNotEmpty ||
          title.isEmpty) {
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
    final hits = body.length > _offMainCodeUnitThreshold
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
