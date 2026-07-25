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
          overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
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

  testWidgets(
    '"Browse channels" dismisses the banner into the compact controller',
    (tester) async {
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
    },
  );

  testWidgets('compact controller fits a short landscape surface', (
    tester,
  ) async {
    final notifier = _MutableCastNotifier(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(device: tv, media: media),
      ),
    );

    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Casting to Sony Bravia'), findsOneWidget);
    expect(find.byTooltip('Pause'), findsOneWidget);
    expect(find.byTooltip('Stop receiver media'), findsOneWidget);
  });

  testWidgets('connection banner fits a short landscape surface', (
    tester,
  ) async {
    final notifier = _MutableCastNotifier(const IptvCastState());

    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

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

    expect(tester.takeException(), isNull);
    expect(find.text('Playing on Sony Bravia'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget);
    expect(find.text('Remote'), findsOneWidget);
  });

  testWidgets('Cast remote fits a short landscape surface', (tester) async {
    final notifier = _MutableCastNotifier(
      IptvCastState(
        session: AiroCastSessionSnapshot.playing(device: tv, media: media),
      ),
    );

    tester.view.physicalSize = const Size(1280, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [iptvCastProvider.overrideWith((ref) => notifier)],
        child: const MaterialApp(
          home: Scaffold(body: IptvCastMiniController()),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Open Cast remote'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Remote for Sony Bravia'), findsOneWidget);
    expect(find.text('Disconnect TV'), findsOneWidget);
  });

  testWidgets('"Open controls" presents the Cast remote sheet', (tester) async {
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
    await tester.pumpAndSettle();

    expect(find.text('Remote for Sony Bravia'), findsOneWidget);
    expect(find.text('P4U Music'), findsWidgets);
    expect(find.byTooltip('Volume up'), findsOneWidget);
    expect(find.byTooltip('Volume down'), findsOneWidget);
    expect(find.byTooltip('Mute'), findsOneWidget);
    expect(find.byTooltip('Stop receiver media'), findsWidgets);
    expect(find.text('Disconnect TV'), findsOneWidget);

    await tester.tap(find.byTooltip('Mute'));
    await tester.pump();
    expect(notifier.fakeController.recordedActions, contains('setVolume:0.0'));
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
    : this._(initial, FakeAiroCastController());

  _MutableCastNotifier._(IptvCastState initial, this.fakeController)
    : super(controller: fakeController, adapter: const IptvCastMediaAdapter()) {
    state = initial;
  }

  final FakeAiroCastController fakeController;

  void setState(IptvCastState next) => state = next;
}
