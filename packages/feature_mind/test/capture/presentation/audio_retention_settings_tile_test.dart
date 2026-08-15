import 'package:feature_mind/src/capture/domain/audio_retention_policy.dart';
import 'package:feature_mind/src/capture/presentation/audio_retention_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: AudioRetentionSettingsTile())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to "keep" and shows the keep copy', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isTrue);
    expect(find.textContaining('stays on this device'), findsOneWidget);
  });

  testWidgets('reflects a previously saved "delete" preference', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'mind_audio_retention_policy':
          AudioRetentionPolicy.deleteAfterTranscript.storageValue,
    });

    await pumpTile(tester);

    final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(tile.value, isFalse);
    expect(find.textContaining('is deleted once'), findsOneWidget);
  });

  testWidgets(
    'toggling off switches to delete-after-transcript and persists it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpTile(tester);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('mind_audio_retention_policy'),
        AudioRetentionPolicy.deleteAfterTranscript.storageValue,
      );
    },
  );
}
