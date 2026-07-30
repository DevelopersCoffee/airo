import 'package:airo_app/features/agent_chat/presentation/screens/device_capability_report_screen.dart';
import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a completed device report from the retained future', (
    tester,
  ) async {
    final report = DeviceCapabilityReport(
      device: const DeviceInfo(
        manufacturer: 'Google',
        model: 'Pixel 9',
        brand: 'Google',
        osVersion: '15',
        sdkVersion: 35,
        isPixelDevice: true,
        supportsOnDeviceAI: true,
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
    expect(find.text('Retry analysis'), findsNothing);
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
