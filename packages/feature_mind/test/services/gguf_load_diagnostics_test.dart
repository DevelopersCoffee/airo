import 'package:feature_mind/src/services/gguf_load_diagnostics.dart';
import 'package:feature_mind/src/services/gguf_load_outcome.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const model = OfflineModelInfo(
    id: 'mind-scribe-qwen',
    name: 'Qwen2.5 0.5B Instruct (Q4_K_M)',
    family: ModelFamily.qwen,
    fileSizeBytes: 491400032,
    filePath: '/tmp/qwen2.5-0.5b-instruct-q4_k_m.gguf',
  );

  test('maps incomplete downloads to repairable copy', () {
    final copy = GgufLoadDiagnostics.describe(
      model: model,
      outcome: const GgufLoadOutcome.incompleteDownload(
        expectedBytes: 491400032,
        foundBytes: 1024,
      ),
      isMacLike: true,
    );

    expect(copy.summary, contains('incomplete'));
    expect(copy.detail, contains('469 MB'));
    expect(copy.repairActions.first, contains('Models'));
  });

  test('maps mac engine failures to actionable copy', () {
    final copy = GgufLoadDiagnostics.describe(
      model: model,
      outcome: const GgufLoadOutcome.engineError('OverBudget needs_mb=2048'),
      isMacLike: true,
    );

    expect(copy.summary, contains('memory'));
    expect(copy.reasonCode, 'memory_blocked');
  });
}
