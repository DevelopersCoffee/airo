import 'package:feature_mind/src/agent_chat/presentation/screens/model_health_center_screen.dart';
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
    expect(find.text('Why can’t this model load?'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Gemma 4B runtime status: Needs attention'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Downloaded: complete. Model artifact is present on this device.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Compatible: blocked. Not enough transient memory.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Retry with a smaller context to free memory.'),
      findsOneWidget,
    );
    expect(find.text('Copy diagnostics'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('Copy runtime diagnostics for Gemma 4B')),
      findsOneWidget,
    );
    await tester.tap(find.text('Copy diagnostics'));
    await tester.pump();
    expect(find.text('Runtime diagnostics copied.'), findsOneWidget);
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
    expect(
      find.bySemanticsLabel(
        'Runtime trace step 1: Initializing runtime, 0 milliseconds.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('live artifact probe offers Resume download for a stale path', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const model = OfflineModelInfo(
      id: 'stale',
      name: 'Stale model',
      family: ModelFamily.gemma,
      fileSizeBytes: 1024,
      filePath: '/models/removed.gguf',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ModelHealthCenterLoaderScreen(
          model: model,
          compatibilityFuture: Future.value(
            ModelCompatibilityResult.compatible(MemorySeverity.safe),
          ),
          artifactPresentFuture: Future<bool>.value(false),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Resume download'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Resume download'), findsOneWidget);
  });
}
