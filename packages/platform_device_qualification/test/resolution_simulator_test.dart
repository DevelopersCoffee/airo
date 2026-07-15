import 'package:core_data/core_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_device_qualification/src/device_qualification_overlay.dart';
import 'package:platform_device_qualification/src/resolution_simulator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'ResolutionSimulator overrides MediaQuery size and navigationMode',
    (WidgetTester tester) async {
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
    },
  );

  testWidgets(
    'ResolutionSimulator passes through native size when set to native',
    (WidgetTester tester) async {
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
    },
  );

  testWidgets(
    'ResolutionSimulator supports compact TV browser qualification viewport',
    (WidgetTester tester) async {
      late MediaQueryData capturedMediaQuery;

      await tester.pumpWidget(
        MaterialApp(
          home: ResolutionSimulator(
            device: SimulatedDevice.androidTvCompactBrowser,
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

      expect(capturedMediaQuery.size.width, 1024);
      expect(capturedMediaQuery.size.height, 576);
      expect(capturedMediaQuery.navigationMode, NavigationMode.directional);
    },
  );

  testWidgets(
    'ResolutionSimulator supports narrow mobile browser fallback viewport',
    (WidgetTester tester) async {
      late MediaQueryData capturedMediaQuery;

      await tester.pumpWidget(
        MaterialApp(
          home: ResolutionSimulator(
            device: SimulatedDevice.mobileBrowserPortrait,
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

      expect(capturedMediaQuery.size.width, 390);
      expect(capturedMediaQuery.size.height, 844);
      expect(capturedMediaQuery.navigationMode, NavigationMode.traditional);
    },
  );

  testWidgets(
    'DeviceQualificationOverlay seeds default playlist through guarded store',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        const MaterialApp(
          home: DeviceQualificationOverlay(
            defaultPlaylistUrl: 'https://example.com/qualification.m3u',
            child: SizedBox.shrink(),
          ),
        ),
      );
      await tester.pump();

      expect(
        prefs.getString(deviceQualificationPlaylistUrlKey),
        'https://example.com/qualification.m3u',
      );
    },
  );

  testWidgets('DeviceQualificationOverlay preserves existing playlist seed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      deviceQualificationPlaylistUrlKey: 'https://example.com/existing.m3u',
    });
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      const MaterialApp(
        home: DeviceQualificationOverlay(
          defaultPlaylistUrl: 'https://example.com/new.m3u',
          child: SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(
      prefs.getString(deviceQualificationPlaylistUrlKey),
      'https://example.com/existing.m3u',
    );
  });

  testWidgets('DeviceQualificationOverlay drops oversized playlist seed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesStore(prefs, maxValueBytes: 32);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceQualificationOverlay(
          playlistStore: store,
          defaultPlaylistUrl: 'https://example.com/${'x' * 64}.m3u',
          child: const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();

    expect(prefs.getString(deviceQualificationPlaylistUrlKey), isNull);
  });
}
