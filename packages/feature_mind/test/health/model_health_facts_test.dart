import 'package:core_ai/core_ai.dart';
import 'package:feature_mind/src/health/model_health_facts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('explicit missing artifact offers resume download', () async {
    final model = OfflineModelInfo(
      id: 'stale-path',
      name: 'Stale Path Model',
      family: ModelFamily.gemma,
      fileSizeBytes: 2048,
      filePath: '/models/stale.gguf',
    );

    final report = await ModelHealthFacts.build(
      model: model,
      compatibility: ModelCompatibilityResult.compatible(MemorySeverity.safe),
      artifactPresent: false,
    );

    expect(report.failureCode, ModelHealthFailureCode.downloadIncomplete);
    expect(report.actions, contains(ModelHealthAction.resumeDownload));
  });
}
