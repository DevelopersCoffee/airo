import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/mind_indic_intelligence.dart';
import 'package:feature_mind/src/settings/indic_generation_settings_tile.dart';
import 'package:feature_mind/src/settings/mind_entitlements_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: IndicGenerationSettingsTile())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Auto generation mode', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);

    expect(
      find.byKey(const Key('indic_generation_settings_tile')),
      findsOneWidget,
    );
    expect(find.text('Auto'), findsOneWidget);
    expect(
      find.textContaining('otherwise Qwen 0.5B'),
      findsOneWidget,
    );
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows pro gate when Indic intelligence is disabled', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mindEntitlementsProvider.overrideWithValue(const NoEntitlements()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: IndicGenerationSettingsTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Indic intelligence packs require Airo Mind Pro.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('indic_generation_settings_dropdown')),
      findsNothing,
    );
  });

  testWidgets('selecting Standard persists preference', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);
    await tester.tap(
      find.byKey(const Key('indic_generation_settings_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard (Qwen)').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('mind_indic_generation_mode'),
      MindIndicGenerationMode.standard.stableId,
    );
  });
}
