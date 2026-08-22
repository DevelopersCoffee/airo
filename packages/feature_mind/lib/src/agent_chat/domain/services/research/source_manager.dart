import 'package:core_workers/core_workers.dart';

import 'document_intelligence.dart';
import 'research_search.dart';
import 'source_classifier.dart';
import 'source_normalizer.dart';

typedef SourceFetcher = Future<String> Function(Uri uri);

class SourceDocument {
  const SourceDocument({
    required this.url,
    required this.title,
    required this.headings,
    required this.paragraphs,
    required this.tables,
    required this.codeBlocks,
    required this.retrievedAt,
    required this.classification,
    this.publishedAt,
    this.modifiedAt,
    this.trustLevel = SourceTrust.untrusted,
  });

  final String url;
  final String title;
  final List<String> headings;
  final List<String> paragraphs;
  final List<String> tables;
  final List<String> codeBlocks;
  final String retrievedAt;
  final String? publishedAt;
  final String? modifiedAt;
  final SourceClassification classification;
  final SourceTrust trustLevel;

  String get evidenceText => [...headings, ...paragraphs, ...tables].join(' ');
}

class SourceAcquireResult {
  const SourceAcquireResult({this.document, this.rejection});

  final SourceDocument? document;
  final String? rejection;
}

/// Fetch → extract → classify → cache. A search hit is not evidence.
class SourceManager {
  SourceManager({required this.fetcher, DateTime Function()? now})
    : now = now ?? DateTime.now;

  final SourceFetcher fetcher;
  final DateTime Function() now;
  final Map<String, SourceDocument> _cache = {};

  Future<SourceAcquireResult> acquire(ResearchHit hit) async {
    final key = canonicalizeUrl(hit.url);
    final cached = _cache[key];
    if (cached != null) {
      return SourceAcquireResult(document: cached);
    }
    try {
      final raw = await fetcher(Uri.parse(hit.url));
      final extracted = _shouldOffload(raw)
          ? await runOffMain(() => extractDocument(raw, url: hit.url))
          : extractDocument(raw, url: hit.url);
      if (extracted.evidenceText.trim().isEmpty) {
        return const SourceAcquireResult(rejection: 'empty document');
      }
      final document = SourceDocument(
        url: key,
        title: extracted.title.isEmpty ? hit.title : extracted.title,
        headings: extracted.headings,
        paragraphs: extracted.paragraphs,
        tables: extracted.tables,
        codeBlocks: extracted.codeBlocks,
        publishedAt: extracted.publishedAt,
        retrievedAt: now().toUtc().toIso8601String(),
        classification: classifySourceUrl(hit.url),
        trustLevel: SourceTrust.untrusted,
      );
      _cache[key] = document;
      return SourceAcquireResult(document: document);
    } catch (error) {
      return SourceAcquireResult(rejection: error.toString());
    }
  }

  Future<List<SourceAcquireResult>> acquireAll(
    List<ResearchHit> hits, {
    int maxParallel = 4,
  }) async {
    final out = <SourceAcquireResult>[];
    final parallel = maxParallel < 1 ? 1 : maxParallel;
    for (var i = 0; i < hits.length; i += parallel) {
      final batch = hits.skip(i).take(parallel).toList(growable: false);
      out.addAll(await Future.wait(batch.map(acquire)));
    }
    return out;
  }
}

bool _shouldOffload(String raw) {
  return raw.length > 50 * 1024 || raw.trimLeft().startsWith('%PDF');
}
