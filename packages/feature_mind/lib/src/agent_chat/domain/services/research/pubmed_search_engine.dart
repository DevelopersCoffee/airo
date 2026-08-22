import 'dart:convert';

import 'research_http.dart';
import 'research_search.dart';

/// PubMed search via NCBI E-utilities. Hits are candidates, not evidence.
class PubMedSearchEngine implements ResearchSearchEngine {
  PubMedSearchEngine({
    this.http = const ResearchHttpClient(),
    this.tool = 'airo_mind',
    this.email = 'noreply@local',
  });

  final ResearchHttpClient http;
  final String tool;
  final String email;

  @override
  String get id => 'pubmed';

  static List<String> parseEsearchIds(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final result = decoded['esearchresult'];
    if (result is! Map) {
      return const [];
    }
    final ids = result['idlist'];
    if (ids is! List) {
      return const [];
    }
    return [
      for (final id in ids)
        if ('$id'.trim().isNotEmpty) '$id'.trim(),
    ];
  }

  static List<ResearchHit> parseEsummaryJson(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      return const [];
    }
    final result = decoded['result'];
    if (result is! Map) {
      return const [];
    }
    final uids = result['uids'];
    if (uids is! List) {
      return const [];
    }
    final hits = <ResearchHit>[];
    for (final uid in uids) {
      final pmid = '$uid'.trim();
      if (pmid.isEmpty) {
        continue;
      }
      final row = result[pmid];
      if (row is! Map) {
        continue;
      }
      final title = '${row['title'] ?? ''}'.trim();
      if (title.isEmpty) {
        continue;
      }
      final source = '${row['source'] ?? ''}'.trim();
      final pubdate = '${row['pubdate'] ?? ''}'.trim();
      final snippet = [source, pubdate].where((part) => part.isNotEmpty).join(
        ' · ',
      );
      hits.add(
        ResearchHit(
          engineId: 'pubmed',
          url: 'https://pubmed.ncbi.nlm.nih.gov/$pmid/',
          title: title,
          snippet: snippet,
        ),
      );
    }
    return hits;
  }

  Map<String, String> _eutilsParams({
    required String db,
    required Map<String, String> extra,
  }) {
    return {'db': db, 'retmode': 'json', 'tool': tool, 'email': email, ...extra};
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (query.trim().isEmpty) {
      return const [];
    }
    final searchUri = Uri.https(
      'eutils.ncbi.nlm.nih.gov',
      '/entrez/eutils/esearch.fcgi',
      _eutilsParams(
        db: 'pubmed',
        extra: {'term': query, 'retmax': '$maxResults'},
      ),
    );
    final searchBody = await http.get(searchUri);
    final ids = parseEsearchIds(searchBody);
    if (ids.isEmpty) {
      return const [];
    }
    final summaryUri = Uri.https(
      'eutils.ncbi.nlm.nih.gov',
      '/entrez/eutils/esummary.fcgi',
      _eutilsParams(db: 'pubmed', extra: {'id': ids.join(',')}),
    );
    final summaryBody = await http.get(summaryUri);
    return parseEsummaryJson(summaryBody);
  }
}
