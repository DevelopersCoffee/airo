import "package:feature_iptv/feature_iptv.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Sony Bravia');
  final media = AiroCastMediaRequest(
    url: Uri.parse('https://example.com/live.m3u8'),
    contentType: 'application/x-mpegURL',
    title: 'P4U Music',
  );

  testWidgets(
    'shows the one-time "Playing on" confirmation on a live connect transition',
    (tester) async {
      final notifier = _MutableCastNotifier(const IptvCastState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvCastProvider.overrideWith((ref) => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: IptvCastMiniController()),
          ),
        ),
      );

      expect(find.text('Play on TV'), findsNothing);
      expect(find.textContaining('Playing on'), findsNothing);

      notifier.setState(
        IptvCastState(
          session: AiroCastSessionSnapshot.playing(device: tv, media: media),
        ),
      );
      await tester.pump();

      expect(find.text('Playing on Sony Bravia'), findsOneWidget);
      expect(
        find.text(
          'P4U Music is playing on your TV. Keep browsing here or use '
          'this device as the remote.',
        ),
        findsOneWidget,
      );
      expect(find.text('Browse channels'), findsOneWidget);
      expect(find.text('Open controls'), findsOneWidget);
    },
  );

  testWidgets('"Browse channels" dismisses the banner into the compact controller', (
    tester,
  ) async {
    final notifier = _MutableCastNotifier(const IptvCastState());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );

    notifier.setState(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(device: tv, media: media),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Browse channels'));
    await tester.pump();

    expect(find.textContaining('Playing on'), findsNothing);
    expect(find.text('Casting to Sony Bravia'), findsOneWidget);
    expect(find.text('Reload'), findsNothing, reason: 'compact by default');
  });

  testWidgets('"Open controls" dismisses the banner into the expanded controller', (
    tester,
  ) async {
    final notifier = _MutableCastNotifier(const IptvCastState());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );

    notifier.setState(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(device: tv, media: media),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Open controls'));
    await tester.pump();

    expect(find.textContaining('Playing on'), findsNothing);
    expect(find.text('Reload'), findsOneWidget);
    expect(find.text('New session'), findsOneWidget);
    expect(find.text('Disconnect'), findsOneWidget);
  });

  testWidgets(
    'no banner for a session that is already connected when the widget mounts '
    '(recovered session, not a live transition)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iptvCastProvider.overrideWith(
              (ref) => _MutableCastNotifier(
                IptvCastState(
                  session: AiroCastSessionSnapshot.playing(
                    device: tv,
                    media: media,
                  ),
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: IptvCastMiniController()),
          ),
        ),
      );

      expect(find.textContaining('Playing on'), findsNothing);
      expect(find.text('Casting to Sony Bravia'), findsOneWidget);
    },
  );

  testWidgets('reconnecting to a different device shows the banner again', (
    tester,
  ) async {
    const secondTv = AiroCastDevice(id: 'tv-2', name: 'Living Room TV');
    final notifier = _MutableCastNotifier(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(device: tv, media: media),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );

    notifier.setState(
      IptvCastState(session: AiroCastSessionSnapshot.disconnected(tv)),
    );
    await tester.pump();
    notifier.setState(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(
          device: secondTv,
          media: media,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Playing on Living Room TV'), findsOneWidget);
  });
}

class _MutableCastNotifier extends IptvCastNotifier {
  _MutableCastNotifier(IptvCastState initial)
    : super(
        controller: FakeAiroCastController(),
        adapter: const IptvCastMediaAdapter(),
      ) {
    state = initial;
  }

  void setState(IptvCastState next) => state = next;
}
