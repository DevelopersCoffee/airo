import "package:feature_iptv/feature_iptv.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:shared_preferences/shared_preferences.dart";

IPTVChannel _channel({ChannelHeaders? headers, String? streamUrl}) {
  return IPTVChannel(
    id: 'c1',
    name: 'News One',
    streamUrl: streamUrl ?? 'https://example.com/stream.m3u8',
    group: 'News',
    headers: headers,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('iptvCastPromptCastableProvider', () {
    test('true for a plain HLS channel with no custom headers', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final castable = container.read(
        iptvCastPromptCastableProvider(_channel()),
      );

      expect(castable, isTrue);
    });

    test('false for a channel requiring custom headers', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final castable = container.read(
        iptvCastPromptCastableProvider(
          _channel(headers: const ChannelHeaders(userAgent: 'custom-agent')),
        ),
      );

      expect(castable, isFalse);
    });
  });

  group('IptvCastPromptCooldown', () {
    test('not dismissed by default', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final dismissed = container.read(iptvCastPromptDismissedProvider);

      expect(dismissed, isFalse);
    });

    test('dismiss() hides the prompt immediately', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      container.read(iptvCastPromptCooldownProvider.notifier).dismiss();

      expect(container.read(iptvCastPromptDismissedProvider), isTrue);
    });

    test('dismissal persists across a fresh provider container', () async {
      final prefs = await SharedPreferences.getInstance();
      final firstContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      firstContainer.read(iptvCastPromptCooldownProvider.notifier).dismiss();
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(secondContainer.dispose);

      expect(
        secondContainer.read(iptvCastPromptDismissedProvider),
        isTrue,
        reason: 'the cooldown must be persisted, not just in-memory',
      );
    });

    test('dismissal expires after the cooldown window elapses', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        kIptvCastPromptDismissedUntilKey,
        DateTime.now().subtract(const Duration(seconds: 1)).toIso8601String(),
      );
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(iptvCastPromptDismissedProvider), isFalse);
    });
  });

  group('iptvCastPromptVisibleProvider', () {
    test('hidden when there is no active channel', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentChannelProvider.overrideWithValue(null),
          iptvCastProvider.overrideWith(
            (ref) => IptvCastNotifier(
              controller: UnavailableAiroCastController(),
              adapter: const IptvCastMediaAdapter(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(iptvCastPromptVisibleProvider), isFalse);
    });

    test('hidden while already casting', () async {
      final fake = FakeAiroCastController(
        devices: const [AiroCastDevice(id: 'tv-1', name: 'Sony Bravia')],
      );
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentChannelProvider.overrideWithValue(_channel()),
          airoCastControllerProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);

      container.read(iptvCastProvider);
      await fake.connect(const AiroCastDevice(id: 'tv-1', name: 'Sony Bravia'));
      await Future<void>.delayed(Duration.zero);

      expect(container.read(iptvCastPromptVisibleProvider), isFalse);
    });

    test('hidden for an uncastable channel', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentChannelProvider.overrideWithValue(
            _channel(headers: const ChannelHeaders(userAgent: 'custom-agent')),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(iptvCastPromptVisibleProvider), isFalse);
    });

    test('hidden after dismissal', () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentChannelProvider.overrideWithValue(_channel()),
        ],
      );
      addTearDown(container.dispose);

      container.read(iptvCastPromptCooldownProvider.notifier).dismiss();

      expect(container.read(iptvCastPromptVisibleProvider), isFalse);
    });

    test(
      'visible for an active, castable channel with no session and no dismissal',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            currentChannelProvider.overrideWithValue(_channel()),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(iptvCastPromptVisibleProvider), isTrue);
      },
    );
  });
}
