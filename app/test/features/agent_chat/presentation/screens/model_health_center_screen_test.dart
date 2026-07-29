import 'package:airo_app/features/agent_chat/presentation/screens/model_health_center_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Why panel, timeline, and accessible recovery action', (
    tester,
  ) async {
    const report = ModelHealthReport(
      modelId: 'gemma-4b',
      modelName: 'Gemma 4B',
      status: ModelHealthReportStatus.recoverable,
      stages: [
        ModelHealthStageResult(
          stage: ModelHealthStage.downloaded,
          status: ModelHealthStageStatus.passed,
          detail: 'Model artifact is present on this device.',
        ),
        ModelHealthStageResult(
          stage: ModelHealthStage.compatible,
          status: ModelHealthStageStatus.blocked,
          detail: 'Not enough transient memory.',
        ),
      ],
      explanation: 'Retry with a smaller context to free memory.',
      failureCode: ModelHealthFailureCode.insufficientMemory,
      actions: [ModelHealthAction.reduceContext],
      availableMemoryMb: 2100,
      requiredMemoryMb: 3338,
    );

    await tester.pumpWidget(
      const MaterialApp(home: ModelHealthCenterScreen(report: report)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime Health Center'), findsOneWidget);
    expect(find.text('Why?'), findsOneWidget);
    expect(
      find.text('Retry with a smaller context to free memory.'),
      findsOneWidget,
    );
    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('Retry with reduced context'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Gemma 4B runtime status')),
      findsOneWidget,
    );
  });
}
