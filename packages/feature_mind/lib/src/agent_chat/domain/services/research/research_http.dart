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
    this.maxRedirects = 3,
  });

  static const defaultAllowedHosts = {
    'en.wikipedia.org',
    'export.arxiv.org',
    'arxiv.org',
    'api.semanticscholar.org',
    'www.semanticscholar.org',
  };

  final Set<String> allowedHosts;
  final int maxBytes;
  final Duration timeout;
  final int maxRedirects;

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

  Uri resolveRedirect(Uri from, String location) {
    if (location.trim().isEmpty) {
      throw const ResearchHttpException(
        'Research redirect did not include a destination.',
      );
    }
    final target = from.resolve(location);
    validate(target);
    return target;
  }

  Future<String> _fetch(Uri uri) async {
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      var current = uri;
      for (var redirects = 0; ; redirects++) {
        final request = await client.getUrl(current);
        request.followRedirects = false;
        final response = await request.close().timeout(timeout);
        if (response.isRedirect) {
          if (redirects >= maxRedirects) {
            await response.drain<void>();
            throw const ResearchHttpException(
              'Research response exceeded redirect limit.',
            );
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          current = resolveRedirect(current, location ?? '');
          continue;
        }
        if (response.statusCode < HttpStatus.ok ||
            response.statusCode >= HttpStatus.multipleChoices) {
          await response.drain<void>();
          throw ResearchHttpException(
            'Research provider returned HTTP ${response.statusCode}.',
          );
        }
        final bytes = await response.fold<List<int>>(<int>[], (buffer, chunk) {
          if (buffer.length + chunk.length > maxBytes) {
            throw const ResearchHttpException(
              'Research response exceeded size limit.',
            );
          }
          return buffer..addAll(chunk);
        });
        return utf8.decode(bytes);
      }
    } finally {
      client.close(force: true);
    }
  }
}
