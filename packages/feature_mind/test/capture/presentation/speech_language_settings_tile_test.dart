import 'package:feature_mind/src/capture/domain/speech_language_mode.dart';
import 'package:feature_mind/src/capture/presentation/speech_language_settings_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SpeechLanguageSettingsTile())),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('defaults to Auto (mixed)', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);

    expect(
      find.byKey(const Key('speech_language_settings_tile')),
      findsOneWidget,
    );
    expect(find.text('Auto (mixed)'), findsOneWidget);
    expect(find.textContaining('multilingual model'), findsOneWidget);
  });

  testWidgets('reflects a previously saved English preference', (tester) async {
    SharedPreferences.setMockInitialValues({
      'mind_speech_language_mode': SpeechLanguageMode.english.storageValue,
    });

    await pumpTile(tester);

    expect(find.text('English'), findsWidgets);
    expect(
      find.textContaining('Skips the multilingual download'),
      findsOneWidget,
    );
  });

  testWidgets('selecting English persists the preference', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await pumpTile(tester);
    await tester.tap(
      find.byKey(const Key('speech_language_settings_dropdown')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('mind_speech_language_mode'),
      SpeechLanguageMode.english.storageValue,
    );
  });
}
