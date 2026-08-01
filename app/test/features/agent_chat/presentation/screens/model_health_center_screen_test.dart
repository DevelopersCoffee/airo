import 'package:airo_app/features/agent_chat/presentation/screens/model_health_center_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows Why panel, timeline, and accessible recovery action', (
    tester,
  ) async {
    final report = ModelHealthReport(
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
      trace: ExecutionTrace(
        entries: [
          ExecutionTraceEntry(
            sequence: 1,
            event: ExecutionTraceEvent.initializing,
            elapsedMs: BigInt.zero,
          ),
          ExecutionTraceEntry(
            sequence: 2,
            event: ExecutionTraceEvent.ready,
            elapsedMs: BigInt.from(120),
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ModelHealthCenterScreen(report: report)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime Health Center'), findsOneWidget);
    expect(find.text('Why?'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Gemma 4B runtime status')),
      findsOneWidget,
    );
    expect(
      find.text('Retry with a smaller context to free memory.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.text('Recommended next steps'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recommended next steps'), findsOneWidget);
    expect(find.text('Retry with reduced context'), findsOneWidget);
    expect(find.text('Runtime trace'), findsOneWidget);
    expect(find.text('Initializing runtime'), findsOneWidget);
    expect(find.text('Runtime ready'), findsOneWidget);
  });
}
