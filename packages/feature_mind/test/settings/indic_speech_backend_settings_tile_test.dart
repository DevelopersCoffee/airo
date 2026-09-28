import 'package:core_entitlements/core_entitlements.dart';
import 'package:feature_mind/src/settings/indic_speech_backend_settings_tile.dart';
import 'package:feature_mind/src/settings/mind_entitlements_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mindEntitlementsProvider.overrideWithValue(
            const LaunchPromoEntitlements(),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: IndicSpeechBackendSettingsTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Auto speech backend', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);

    expect(
      find.byKey(const Key('indic_speech_backend_settings_tile')),
      findsOneWidget,
    );
    expect(find.text('Auto'), findsOneWidget);
  });

  testWidgets('does not advertise unpublished speech backends', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);
    await tester.tap(
      find.byKey(const Key('indic_speech_backend_settings_dropdown')),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Sarvam Edge'), findsNothing);
    expect(find.text('On-device speech'), findsOneWidget);
  });
}
