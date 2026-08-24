import 'package:feature_mind/src/capture/presentation/live_capture_settings_tiles.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('desktop shows live insight and intelligence controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LiveCaptureSettingsTiles()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('live_insights_settings_tile')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('live_intelligence_settings_tile')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('live_intelligence_settings_dropdown')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Prefer full insights'), findsOneWidget);
      expect(find.text('Transcript only'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('mobile hides live capture settings', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: LiveCaptureSettingsTiles()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('live_insights_settings_tile')), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
