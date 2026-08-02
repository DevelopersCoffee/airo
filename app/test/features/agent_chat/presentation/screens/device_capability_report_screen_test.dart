import 'package:airo_app/features/agent_chat/presentation/screens/device_capability_report_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a completed device report from the retained future', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final report = DeviceCapabilityReport(
      device: const DeviceInfo(
        manufacturer: 'Google',
        model: 'Pixel 9',
        brand: 'Google',
        osVersion: '15',
        sdkVersion: 35,
        isPixelDevice: true,
        supportsOnDeviceAI: true,
        cpuSummary: 'Tensor G4 · 8 cores',
        gpuSummary: 'Not reported by platform adapter',
        npuSummary: 'On-device AI service reported',
        storageSummary: '42.0 GB free of 128.0 GB',
        thermalSummary: 'Nominal',
      ),
      memory: MemoryInfo.fromMegabytes(totalMB: 16384, availableMB: 8192),
      recommendedModels: const [],
      generatedAt: DateTime(2026, 7, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCapabilityReportLoaderScreen(
          reportFuture: Future<DeviceCapabilityReport>.delayed(
            Duration.zero,
            () => report,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Pixel 9'), findsOneWidget);
    expect(find.text('8192 MB available of 16384 MB total.'), findsOneWidget);
    expect(find.text('Runtime diagnostics'), findsOneWidget);
    expect(find.text('Transient memory'), findsOneWidget);
    expect(find.text('Hardware facts'), findsOneWidget);
    expect(find.textContaining('CPU: Tensor G4 · 8 cores'), findsOneWidget);
    expect(
      find.textContaining('GPU: Not reported by platform adapter'),
      findsOneWidget,
    );
    expect(
      find.textContaining('NPU: On-device AI service reported'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Storage: 42.0 GB free of 128.0 GB'),
      findsOneWidget,
    );
    expect(find.textContaining('Thermals: Nominal'), findsOneWidget);
    expect(find.text('On-device AI service'), findsOneWidget);
    expect(find.text('Pixel runtime profile'), findsOneWidget);
    expect(find.text('Final runtime preflight'), findsOneWidget);
    expect(find.text('Copy report'), findsOneWidget);
    await tester.tap(find.text('Copy report'));
    await tester.pump();
    expect(find.text('Device report copied.'), findsOneWidget);
    expect(find.text('Retry analysis'), findsNothing);
  });

  testWidgets('surfaces model fit warnings in the report', (tester) async {
    tester.view.physicalSize = const Size(1200, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final report = DeviceCapabilityReport(
      device: DeviceInfo.unknown(),
      memory: MemoryInfo.fromMegabytes(totalMB: 8192, availableMB: 1024),
      recommendedModels: const [
        DeviceModelRecommendation(
          modelId: 'gemma-4b',
          modelName: 'Gemma 4B',
          severity: MemorySeverity.critical,
          estimatedMemoryMb: 3600,
          expectedTokensPerSecond: 8,
        ),
        DeviceModelRecommendation(
          modelId: 'vision-large',
          modelName: 'Vision Large',
          severity: MemorySeverity.blocked,
          estimatedMemoryMb: 7000,
          expectedTokensPerSecond: 2,
        ),
      ],
      generatedAt: DateTime(2026, 7, 30),
    );

    await tester.pumpWidget(
      MaterialApp(home: DeviceCapabilityReportScreen(report: report)),
    );

    expect(find.text('Model fit warnings'), findsOneWidget);
    expect(
      find.textContaining('1 model(s) may need reduced context'),
      findsOneWidget,
    );
    expect(
      find.textContaining('1 model(s) need a smaller plan or model'),
      findsOneWidget,
    );
    expect(find.textContaining('Expected 8.0 tok/s'), findsOneWidget);
    expect(find.textContaining('Expected 2.0 tok/s'), findsOneWidget);
  });

  test('renders support-safe device report markdown', () {
    final report = DeviceCapabilityReport(
      device: const DeviceInfo(
        manufacturer: 'Google',
        model: 'Pixel 9',
        brand: 'Google',
        osVersion: '15',
        sdkVersion: 35,
        isPixelDevice: true,
        supportsOnDeviceAI: true,
        cpuSummary: 'Tensor G4 · 8 cores',
        gpuSummary: 'Vulkan capable',
        npuSummary: 'On-device AI service reported',
        storageSummary: '42.0 GB free of 128.0 GB',
        thermalSummary: 'Nominal',
      ),
      memory: MemoryInfo.fromMegabytes(totalMB: 16384, availableMB: 8192),
      recommendedModels: const [
        DeviceModelRecommendation(
          modelId: 'gemma-4b',
          modelName: 'Gemma 4B',
          severity: MemorySeverity.safe,
          estimatedMemoryMb: 3338,
          expectedTokensPerSecond: 12.4,
        ),
      ],
      generatedAt: DateTime.utc(2026, 8, 2),
    );

    final markdown = report.toMarkdown();

    expect(markdown, contains('# Airo Device Capability Report'));
    expect(markdown, contains('| Device | `Google Pixel 9` |'));
    expect(markdown, contains('| On-device AI | `true` |'));
    expect(
      markdown,
      contains('| Memory | `8192 MB available of 16384 MB total.` |'),
    );
    expect(markdown, contains('- `safe` Pixel runtime profile:'));
    expect(
      markdown,
      contains(
        '- `gemma-4b` Gemma 4B: `safe`, 3338 MB estimated memory, 12.4 tok/s expected',
      ),
    );
    expect(markdown, isNot(contains('/Users/')));
    expect(markdown, isNot(contains('/storage/')));
  });

  testWidgets('shows a retry action when device analysis fails', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceCapabilityReportLoaderScreen(
          reportFuture: Future<DeviceCapabilityReport>.delayed(
            Duration.zero,
            () => throw StateError('boom'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Airo could not finish device analysis.'),
      findsOneWidget,
    );
    expect(find.text('Retry analysis'), findsOneWidget);
  });
}
