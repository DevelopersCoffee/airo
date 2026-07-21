import "package:feature_iptv/feature_iptv.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = IPTVChannel(
    id: 'c1',
    name: 'News One',
    streamUrl: 'https://example.com/stream.m3u8',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<SharedPreferences> prefs() => SharedPreferences.getInstance();

  testWidgets('renders nothing when the prompt is not visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          currentChannelProvider.overrideWithValue(null),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: IptvCastPromptCard(channel: channel, onChooseTv: null),
          ),
        ),
      ),
    );

    expect(find.text('Play on TV'), findsNothing);
  });

  testWidgets('shows the CV-028 prompt copy for a castable channel', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          currentChannelProvider.overrideWithValue(channel),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: IptvCastPromptCard(channel: channel, onChooseTv: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Play on TV'), findsOneWidget);
    expect(
      find.text('Send this channel to a Chromecast-enabled TV.'),
      findsOneWidget,
    );
    expect(find.text('Choose a TV'), findsOneWidget);
  });

  testWidgets('Choose a TV invokes onChooseTv', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          currentChannelProvider.overrideWithValue(channel),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: IptvCastPromptCard(
              channel: channel,
              onChooseTv: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Choose a TV'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('dismissing hides the prompt and starts the cooldown', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(await prefs()),
        currentChannelProvider.overrideWithValue(channel),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: IptvCastPromptCard(channel: channel, onChooseTv: () {}),
          ),
        ),
      ),
    );

    expect(find.text('Play on TV'), findsOneWidget);

    await tester.tap(find.byTooltip('Not now'));
    await tester.pump();

    expect(find.text('Play on TV'), findsNothing);
    expect(container.read(iptvCastPromptDismissedProvider), isTrue);
  });

  testWidgets('never shown for a channel requiring custom headers', (
    tester,
  ) async {
    const uncastable = IPTVChannel(
      id: 'c2',
      name: 'Needs Headers',
      streamUrl: 'https://example.com/stream.m3u8',
      headers: ChannelHeaders(userAgent: 'custom-agent'),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(await prefs()),
          currentChannelProvider.overrideWithValue(uncastable),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: IptvCastPromptCard(
              channel: uncastable,
              onChooseTv: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Play on TV'), findsNothing);
  });
}
