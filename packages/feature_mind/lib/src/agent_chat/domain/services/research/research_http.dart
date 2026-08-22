import 'dart:convert';
import 'dart:io';

class ResearchHttpException implements Exception {
  const ResearchHttpException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// HTTPS + host allowlist + size/timeout caps. Retrieved pages are content,
/// never tool endpoints.
class ResearchHttpClient {
  const ResearchHttpClient({
    this.allowedHosts = defaultAllowedHosts,
    this.maxBytes = 256 * 1024,
    this.timeout = const Duration(seconds: 8),
  });

  static const defaultAllowedHosts = {
    'en.wikipedia.org',
    'export.arxiv.org',
    'arxiv.org',
  };

  final Set<String> allowedHosts;
  final int maxBytes;
  final Duration timeout;

  void validate(Uri uri) {
    if (uri.scheme != 'https') {
      throw const ResearchHttpException(
        'Only HTTPS research fetches are allowed.',
      );
    }
    if (!allowedHosts.contains(uri.host)) {
      throw ResearchHttpException(
        'Host ${uri.host} is not an allowed research provider.',
      );
    }
  }

  Future<String> get(Uri uri) {
    validate(uri);
    return _fetch(uri);
  }

  Future<String> _fetch(Uri uri) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(timeout);
      final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
        if (buffer.length + chunk.length > maxBytes) {
          throw const ResearchHttpException(
            'Research response exceeded size limit.',
          );
        }
        return buffer..addAll(chunk);
      });
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }
}
