import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feature_mind/src/capture/application/transcription_mode_preference.dart';
import 'package:feature_mind/src/capture/domain/transcription_mode.dart';
import 'package:feature_mind/src/capture/presentation/transcription_mode_settings_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('mobile host shows only After recording in dropdown', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [TranscriptionModeSettingsTile()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('After recording'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
    expect(find.text('Live + refine'), findsNothing);
    expect(find.textContaining('desktop-only'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('desktop host lists all transcription modes', (tester) async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: ListView(
              children: const [TranscriptionModeSettingsTile()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('transcription_mode_settings_dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('After recording'), findsWidgets);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Live + refine'), findsOneWidget);
    expect(find.textContaining('Preview on desktop'), findsOneWidget);

    debugDefaultTargetPlatformOverride = null;
  });
}
