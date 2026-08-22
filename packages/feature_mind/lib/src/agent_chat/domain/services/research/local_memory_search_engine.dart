import '../../../../runtime/models/log_models.dart';
import '../../../../runtime/ports/operation_log_port.dart';
import 'research_library.dart';
import 'research_library_log.dart';
import 'research_search.dart';

/// Searches the durable research library in the operation log.
class LocalMemorySearchEngine implements ResearchSearchEngine {
  LocalMemorySearchEngine({required OperationLogPort operationLog})
    : _operationLog = operationLog;

  final OperationLogPort _operationLog;

  @override
  String get id => 'local_memory';

  static List<ResearchHit> hitsFor({
    required String query,
    required List<ResearchLibraryEntry> entries,
    int maxResults = 5,
  }) {
    if (query.trim().isEmpty) {
      return const [];
    }
    final key = topicKeyFor(query);
    final normalized = query.trim().toLowerCase();
    final hits = <ResearchHit>[];
    for (final entry in entries) {
      if (!_matches(entry, key, normalized)) {
        continue;
      }
      if (entry.sourceUrls.isEmpty) {
        continue;
      }
      hits.add(
        ResearchHit(
          engineId: 'local_memory',
          url: entry.sourceUrls.first,
          title: entry.question,
          snippet: entry.findings.isNotEmpty
              ? entry.findings.first
              : entry.question,
          trustLevel: SourceTrust.system,
        ),
      );
      if (hits.length >= maxResults) {
        break;
      }
    }
    return hits;
  }

  static bool _matches(
    ResearchLibraryEntry entry,
    String topicKey,
    String normalizedQuery,
  ) {
    if (entry.topicKey == topicKey) {
      return true;
    }
    return entry.question.toLowerCase().contains(normalizedQuery);
  }

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    final entries = await _loadEntries();
    return hitsFor(query: query, entries: entries, maxResults: maxResults);
  }

  Future<List<ResearchLibraryEntry>> _loadEntries() async {
    final entries = <ResearchLibraryEntry>[];
    try {
      final count = await _operationLog.count();
      if (count == 0) {
        return entries;
      }
      final limit = count < 200 ? count : 200;
      final ops = await _operationLog.range(offset: 0, limit: limit);
      for (final op in ops) {
        if (op.kind != MindOpKind.researchLibrary || op.detail.isEmpty) {
          continue;
        }
        try {
          entries.add(ResearchLibraryEntry.fromRecord(op.detail));
        } on FormatException {
          continue;
        }
      }
    } on Object {
      return const [];
    }
    return entries;
  }
}
