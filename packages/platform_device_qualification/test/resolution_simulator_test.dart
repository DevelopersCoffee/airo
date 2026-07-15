import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_qualification/src/resolution_simulator.dart';

void main() {
  testWidgets('ResolutionSimulator overrides MediaQuery size and navigationMode', (WidgetTester tester) async {
    late MediaQueryData capturedMediaQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: ResolutionSimulator(
          device: SimulatedDevice.androidTv1080p,
          showBezel: false,
          child: Builder(
            builder: (context) {
              capturedMediaQuery = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Verify overridden size matches 1920x1080 (Android TV 1080p profile)
    expect(capturedMediaQuery.size.width, 1920);
    expect(capturedMediaQuery.size.height, 1080);
    expect(capturedMediaQuery.navigationMode, NavigationMode.directional);
  });

  testWidgets('ResolutionSimulator passes through native size when set to native', (WidgetTester tester) async {
    late MediaQueryData capturedMediaQuery;

    await tester.pumpWidget(
      MaterialApp(
        home: ResolutionSimulator(
          device: SimulatedDevice.native,
          showBezel: false,
          child: Builder(
            builder: (context) {
              capturedMediaQuery = MediaQuery.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    // Native mode does not override sizes, so it matches the test window size (800x600 by default in widget tests)
    expect(capturedMediaQuery.size.width, 800);
    expect(capturedMediaQuery.size.height, 600);
    expect(capturedMediaQuery.navigationMode, NavigationMode.traditional);
  });
}
