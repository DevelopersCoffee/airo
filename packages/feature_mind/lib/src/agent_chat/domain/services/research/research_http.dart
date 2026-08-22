import 'dart:convert';
import 'dart:io';

import 'research_http_cache.dart';
import 'source_normalizer.dart' show canonicalizeUrl;

class ResearchHttpException implements Exception {
  const ResearchHttpException(this.message);
  final String message;

  @override
  String toString() => message;
}

typedef ResearchHttpTransport =
    Future<ResearchHttpTransportResponse> Function(Uri uri, Duration timeout);

class ResearchHttpTransportResponse {
  const ResearchHttpTransportResponse({
    required this.statusCode,
    required this.chunks,
    this.location,
    this.close = _noop,
  });

  final int statusCode;
  final Stream<List<int>> chunks;
  final String? location;
  final void Function() close;

  bool get isRedirect => const {
    HttpStatus.movedPermanently,
    HttpStatus.found,
    HttpStatus.seeOther,
    HttpStatus.temporaryRedirect,
    HttpStatus.permanentRedirect,
  }.contains(statusCode);
}

void _noop() {}

Future<ResearchHttpTransportResponse> _ioResearchHttpTransport(
  Uri uri,
  Duration timeout,
) async {
  final client = HttpClient()..connectionTimeout = timeout;
  try {
    final request = await client.getUrl(uri);
    request.followRedirects = false;
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

/// HTTPS + host allowlist + size/timeout caps. Retrieved pages are content,
/// never tool endpoints.
class ResearchHttpClient {
  const ResearchHttpClient({
    this.allowedHosts = defaultAllowedHosts,
    this.allowedOrigins = const {},
    this.maxBytes = 256 * 1024,
    this.timeout = const Duration(seconds: 8),
    this.maxRedirects = 3,
    this.transport = _ioResearchHttpTransport,
    this.cache,
  });

  static const defaultAllowedHosts = {
    'en.wikipedia.org',
    'export.arxiv.org',
    'arxiv.org',
    'api.semanticscholar.org',
    'www.semanticscholar.org',
    'eutils.ncbi.nlm.nih.gov',
    'pubmed.ncbi.nlm.nih.gov',
    'api.github.com',
    'github.com',
    'api.crossref.org',
    'doi.org',
  };

  final Set<String> allowedHosts;
  final Set<String> allowedOrigins;
  final int maxBytes;
  final Duration timeout;
  final int maxRedirects;
  final ResearchHttpTransport transport;
  final ResearchHttpCache? cache;

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
    if (allowedOrigins.isNotEmpty && !allowedOrigins.contains(uri.origin)) {
      throw ResearchHttpException(
        'Origin ${uri.origin} is not an allowed research provider.',
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
    final cacheKey = canonicalizeUrl(uri.toString());
    final activeCache = cache ?? researchHttpCache;
    final cached = activeCache.read(cacheKey, DateTime.now());
    if (cached != null) {
      return cached;
    }

    var current = uri;
    for (var redirects = 0; ; redirects++) {
      final response = await transport(current, timeout).timeout(timeout);
      try {
        if (response.isRedirect) {
          if (redirects >= maxRedirects) {
            throw const ResearchHttpException(
              'Research response exceeded redirect limit.',
            );
          }
          current = resolveRedirect(current, response.location ?? '');
          continue;
        }
        if (response.statusCode < HttpStatus.ok ||
            response.statusCode >= HttpStatus.multipleChoices) {
          throw ResearchHttpException(
            'Research provider returned HTTP ${response.statusCode}.',
          );
        }
        final bytes = await response.chunks
            .fold<List<int>>(<int>[], (buffer, chunk) {
              if (buffer.length + chunk.length > maxBytes) {
                throw const ResearchHttpException(
                  'Research response exceeded size limit.',
                );
              }
              return buffer..addAll(chunk);
            })
            .timeout(timeout);
        final body = utf8.decode(bytes);
        activeCache.write(cacheKey, body, DateTime.now());
        return body;
      } finally {
        response.close();
      }
    }
  }
}
