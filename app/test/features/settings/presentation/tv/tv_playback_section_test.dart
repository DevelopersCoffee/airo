import 'package:airo_app/features/settings/presentation/tv/tv_playback_section.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> buildContainer({
    List<Override> extraOverrides = const [],
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...extraOverrides,
      ],
    );
  }

  testWidgets('lists every AiroPlaybackViewFit option', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(find.text('Fit (letterboxed)'), findsOneWidget);
    expect(find.text('Fill screen (cropped)'), findsOneWidget);
    expect(find.text('Fill width'), findsOneWidget);
    expect(find.text('Stretch to fill'), findsOneWidget);
    expect(find.text('Picture-in-picture'), findsOneWidget);
  });

  testWidgets('toggling PiP updates the persisted preference', (tester) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(container.read(pictureInPicturePreferenceProvider), isTrue);

    await tester.tap(find.text('Picture-in-picture'));
    await tester.pump();

    expect(container.read(pictureInPicturePreferenceProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getBool(PictureInPicturePreferenceNotifier.storageKey),
      isFalse,
    );
  });

  testWidgets('selecting a fit option updates videoAspectRatioProvider', (
    tester,
  ) async {
    final container = await buildContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(
      container.read(videoAspectRatioProvider),
      AiroPlaybackViewFit.contain,
    );

    await tester.tap(find.text('Fill screen (cropped)'));
    await tester.pump();

    expect(container.read(videoAspectRatioProvider), AiroPlaybackViewFit.cover);
  });

  testWidgets('renders playback settings extension sections', (tester) async {
    final container = await buildContainer(
      extraOverrides: [
        playbackSettingsExtraSectionsProvider.overrideWithValue(const [
          ListTile(title: Text('Injected playback setting')),
        ]),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TvPlaybackSection())),
      ),
    );
    await tester.pump();

    expect(find.text('Injected playback setting'), findsOneWidget);
    expect(find.text('Fit (letterboxed)'), findsOneWidget);
  });
}
