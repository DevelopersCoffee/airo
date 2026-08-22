import '../../../../runtime/mind_runtime.dart' show MindPortUnavailable;
import '../../../../runtime/models/log_models.dart';
import '../../../../runtime/ports/operation_log_port.dart';
import 'research_checkpoint.dart';

/// Appends a research checkpoint to the operation log (`I2` — no sidecar store).
Future<int?> appendResearchCheckpointOp({
  required OperationLogPort log,
  required ResearchCheckpoint checkpoint,
}) async {
  try {
    return await log.append(
      kind: MindOpKind.researchCheckpoint,
      title: 'Research ${checkpoint.state.name}: ${checkpoint.question}',
      contextId: checkpoint.jobId,
      detail: checkpoint.toRecord(),
    );
  } on MindPortUnavailable {
    return null;
  }
}

/// Newest non-terminal research checkpoint, if any.
Future<ResearchCheckpoint?> latestResumableResearchCheckpoint(
  OperationLogPort log,
) async {
  try {
    final count = await log.count();
    if (count == 0) {
      return null;
    }
    final limit = count < 200 ? count : 200;
    final ops = await log.range(offset: 0, limit: limit);
    for (final op in ops) {
      if (op.kind != MindOpKind.researchCheckpoint || op.detail.isEmpty) {
        continue;
      }
      try {
        final checkpoint = ResearchCheckpoint.fromRecord(op.detail);
        if (!checkpoint.isTerminal) {
          return checkpoint;
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
