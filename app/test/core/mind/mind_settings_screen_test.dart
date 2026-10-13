import 'package:airo_app/core/mind/mind_settings_screen.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_assistant_host_adapter.dart';

void main() {
  testWidgets('theme segments and host sections render', (tester) async {
    final host = FakeAssistantHostAdapter();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assistantHostAdapterProvider.overrideWithValue(host),
          mindDesktopThemeModeProvider.overrideWith((ref) => ThemeMode.dark),
        ],
        child: const MaterialApp(home: MindSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Meeting recordings'), findsOneWidget);
    expect(
      find.byKey(const Key('fake-ai-preferences-section')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Offline models'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Offline models'), findsOneWidget);
  });

  testWidgets('selecting light theme updates mindDesktopThemeModeProvider', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        assistantHostAdapterProvider.overrideWithValue(
          FakeAssistantHostAdapter(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(mindDesktopThemeModeProvider), ThemeMode.dark);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: MindSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();

    expect(container.read(mindDesktopThemeModeProvider), ThemeMode.light);
    expect(
      container.read(mindDesktopThemeModeProvider),
      isNot(ThemeMode.dark),
    );
  });
}
