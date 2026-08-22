import 'dart:convert';
import 'dart:io';

import 'research_http.dart';
import 'research_search.dart';

Future<ResearchHttpTransportResponse> _crossrefTransport(
  Uri uri,
  Duration timeout,
) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Airo-Mind-Research/1.0 (mailto:noreply@local)',
    );
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

/// Crossref scholarly metadata search. Hits are candidates, not evidence.
class CrossrefSearchEngine implements ResearchSearchEngine {
  CrossrefSearchEngine({ResearchHttpClient? http})
    : http =
          http ??
          const ResearchHttpClient(
            allowedHosts: {'api.crossref.org', 'doi.org'},
            transport: _crossrefTransport,
          );

  final ResearchHttpClient http;

  @override
  String get id => 'crossref';

  static List<ResearchHit> parseSearchJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final message = decoded['message'];
    if (message is! Map) {
      return const [];
    }
    final items = message['items'];
    if (items is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final row in items) {
      if (row is! Map) {
        continue;
      }
      final titleField = row['title'];
      final title = titleField is List && titleField.isNotEmpty
          ? '${titleField.first}'.trim()
          : '${titleField ?? ''}'.trim();
      if (title.isEmpty) {
        continue;
      }
      final url = _workUrl(row);
      if (url == null) {
        continue;
      }
      hits.add(
        ResearchHit(
          engineId: 'crossref',
          url: url,
          title: title,
          snippet: _snippet(row),
        ),
      );
    }
    return hits;
  }

  static String? _workUrl(Map<dynamic, dynamic> row) {
    final raw = '${row['URL'] ?? ''}'.trim();
    final parsed = Uri.tryParse(raw);
    if (parsed != null &&
        parsed.scheme == 'https' &&
        parsed.host.isNotEmpty &&
        parsed.userInfo.isEmpty) {
      return parsed.toString();
    }
    final doi = '${row['DOI'] ?? ''}'.trim();
    if (doi.isEmpty) {
      return null;
    }
    return 'https://doi.org/$doi';
  }

  static String _snippet(Map<dynamic, dynamic> row) {
    final abstract = '${row['abstract'] ?? ''}'.trim();
    if (abstract.isNotEmpty) {
      return abstract;
    }
    final publisher = '${row['publisher'] ?? ''}'.trim();
    final issued = row['issued'];
    if (issued is Map) {
      final parts = issued['date-parts'];
      if (parts is List && parts.isNotEmpty && parts.first is List) {
        final dateParts = parts.first as List;
        if (dateParts.isNotEmpty) {
          return [publisher, dateParts.join('-')]
              .where((part) => part.isNotEmpty)
              .join(' · ');
        }
      }
    }
    return publisher;
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final uri = Uri.https('api.crossref.org', '/works', {
      'query': query,
      'rows': '$maxResults',
    });
    final body = await http.get(uri);
    return parseSearchJson(body);
  }
}
