import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer({
    Map<String, Object> initialValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<void> pumpSection(
    WidgetTester tester,
    ProviderContainer container, {
    required bool forTv,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: AccessibilitySettingsSection(forTv: forTv)),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('selecting Large writes tv_font_mode and scale is 1.25', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpSection(tester, container, forTv: true);

    await tester.tap(find.text('Large'));
    await tester.pump();

    expect(container.read(tvFontModeProvider), TvFontMode.large);
    expect(container.read(tvFontModeProvider).scale, 1.25);
    expect(
      container.read(sharedPreferencesProvider).getString(tvFontModeStorageKey),
      TvFontMode.large.stableId,
    );
  });

  testWidgets('toggling captions writes caption_preference_enabled', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpSection(tester, container, forTv: false);

    expect(find.byType(Switch), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(container.read(captionPreferenceProvider).enabled, isTrue);
    expect(
      container
          .read(sharedPreferencesProvider)
          .getBool(captionPreferenceEnabledStorageKey),
      isTrue,
    );
  });

  testWidgets('TV captions Off/On rows have semantic labels and no Switch', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpSection(tester, container, forTv: true);

    expect(find.byType(Switch), findsNothing);
    TvFocusable focusableWithLabel(String visible) {
      return tester.widget<TvFocusable>(
        find.ancestor(
          of: find.text(visible),
          matching: find.byType(TvFocusable),
        ),
      );
    }

    expect(focusableWithLabel('Off').semanticLabel, 'Captions off');
    expect(focusableWithLabel('On').semanticLabel, 'Captions on');
    expect(focusableWithLabel('Standard').semanticLabel, 'Standard');
    expect(focusableWithLabel('Large').semanticLabel, 'Large');
    expect(focusableWithLabel('Extra large').semanticLabel, 'Extra large');
  });

  testWidgets('shows honest captions copy and null-language status', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);
    await pumpSection(tester, container, forTv: true);

    expect(
      find.text(
        'On reapplies the last language you picked in the player. '
        'If you have not picked one yet, captions stay off until you do.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Text size applies to channel names in the library.'),
      findsOneWidget,
    );
    expect(
      find.text('No language saved — pick one in the player.'),
      findsOneWidget,
    );
    expect(find.textContaining('stream default'), findsNothing);
  });

  testWidgets('shows saved language status when languageCode is eng', (
    tester,
  ) async {
    final container = await buildContainer(
      initialValues: {
        captionPreferenceEnabledStorageKey: true,
        captionPreferenceLanguageStorageKey: 'eng',
      },
    );
    addTearDown(container.dispose);
    await pumpSection(tester, container, forTv: false);

    expect(find.text('Saved language: eng.'), findsOneWidget);
  });
}
