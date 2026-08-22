import '../../../../runtime/mind_runtime.dart' show MindPortUnavailable;
import '../../../../runtime/models/log_models.dart';
import '../../../../runtime/ports/operation_log_port.dart';
import 'research_library.dart';

Future<int?> appendResearchLibraryOp({
  required OperationLogPort log,
  required ResearchLibraryEntry entry,
}) async {
  try {
    return await log.append(
      kind: MindOpKind.researchLibrary,
      title: 'Research library: ${entry.question}',
      contextId: entry.topicKey,
      detail: entry.toRecord(),
    );
  } on MindPortUnavailable {
    return null;
  }
}

/// Newest library entry for this topic, scanning at most 200 ops.
Future<ResearchLibraryEntry?> latestLibraryEntryFor(
  OperationLogPort log,
  String question,
) async {
  try {
    final count = await log.count();
    if (count == 0) {
      return null;
    }
    final key = topicKeyFor(question);
    final limit = count < 200 ? count : 200;
    final ops = await log.range(offset: 0, limit: limit);
    for (final op in ops) {
      if (op.kind != MindOpKind.researchLibrary || op.detail.isEmpty) {
        continue;
      }
      try {
        final entry = ResearchLibraryEntry.fromRecord(op.detail);
        if (entry.topicKey == key) {
          return entry;
        }
      } on FormatException {
        continue;
      }
    }
    return null;
  } on MindPortUnavailable {
    return null;
  }
}
