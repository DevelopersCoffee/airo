import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/screens/settings/playback_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('resume last channel switch defaults on and writes the pref', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlaybackSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Resume last channel'), findsOneWidget);
    expect(
      find.text('Open the last live channel when Aika Stream starts.'),
      findsOneWidget,
    );
    expect(container.read(resumeLastChannelEnabledProvider), isTrue);

    await tester.tap(
      find.byKey(const ValueKey('playback-resume-last-channel-toggle')),
    );
    await tester.pump();

    expect(container.read(resumeLastChannelEnabledProvider), isFalse);
  });

  testWidgets('sleep timer 30 minutes writes remaining', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlaybackSettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sleep timer'), findsOneWidget);
    expect(
      find.text('Stop playback and return to Library after this time.'),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const ValueKey('playback-sleep-timer-30')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-30')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 30);

    await tester.ensureVisible(
      find.byKey(const ValueKey('playback-sleep-timer-0')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('playback-sleep-timer-0')));
    await tester.pump();
    expect(container.read(sleepTimerRemainingProvider), 0);
  });
}
