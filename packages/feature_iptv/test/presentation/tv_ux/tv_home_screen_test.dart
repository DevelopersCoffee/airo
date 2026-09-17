import 'dart:async';

import 'package:feature_iptv/application/providers/tv_playlist_pairing_provider.dart';
import 'package:feature_iptv/application/services/tv_playlist_pairing_server.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:feature_iptv/presentation/tv_ux/tv_home_screen.dart';
import 'package:feature_iptv/presentation/tv_ux/tv_playlist_import_success_dialog.dart';
import 'package:feature_iptv/presentation/tv_ux/tv_playlist_url_dialog.dart';
import 'package:feature_iptv/presentation/tv_ux/sections/filter_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

const _bbc = IPTVChannel(
  id: 'bbc',
  name: 'BBC One HD',
  streamUrl: 'https://example.com/bbc.m3u8',
  group: 'UK',
);

const _cnn = IPTVChannel(
  id: 'cnn',
  name: 'CNN International',
  streamUrl: 'https://example.com/cnn.m3u8',
);

const _longName = IPTVChannel(
  id: 'long',
  name: 'This is a forty-seven-plus character channel name that must ellipsis',
  streamUrl: 'https://example.com/long.m3u8',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHome(
    WidgetTester tester, {
    List<IPTVChannel> channels = const [],
    List<IPTVChannel> recents = const [],
    List<IPTVChannel> favorites = const [],
    ValueChanged<IPTVChannel>? onPlayChannel,
    VoidCallback? onSeeAllLiveTv,
    TvPlaylistPairingServer Function()? pairingFactory,
    List<Override> extraOverrides = const [],
    Size size = const Size(1280, 720),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvChannelsProvider.overrideWith((ref) async => channels),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => recents),
          favoriteChannelsProvider.overrideWith((ref) async => favorites),
          localMediaLibraryCapabilitiesProvider.overrideWith(
            (ref) async => const LocalMediaLibraryCapabilities(
              removableStorage: true,
              dlnaUpnp: true,
            ),
          ),
          tvPlaylistPairingServerFactoryProvider.overrideWithValue(
            pairingFactory ?? () => _FakePairingServer(never: true),
          ),
          ...extraOverrides,
        ],
        child: MaterialApp(
          home: TvHomeScreen(
            onPlayChannel: onPlayChannel,
            onSeeAllLiveTv: onSeeAllLiveTv,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('empty Home is QR-primary with URL USB Network secondary', (
    tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Aika Stream'), findsOneWidget);
    expect(find.text('Your media. Your player.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('tv-playlist-qr-waiting')),
      findsOneWidget,
    );
    expect(find.textContaining('same Wi-Fi'), findsOneWidget);
    expect(find.text('Or enter URL manually'), findsOneWidget);
    expect(find.text('Browse USB'), findsOneWidget);
    expect(find.text('Browse network'), findsOneWidget);
    expect(find.text('Continue Watching'), findsNothing);
    expect(find.text('Live TV'), findsNothing);
    expect(find.byType(FilterRow), findsNothing);
  });

  testWidgets('hides empty Continue Watching and falls back to Live TV', (
    tester,
  ) async {
    await pumpHome(tester, channels: const [_bbc, _cnn, _longName]);

    expect(find.text('Continue Watching'), findsNothing);
    expect(find.text('Your Favorites'), findsNothing);
    expect(find.text('Recently Added'), findsNothing);
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('BBC One HD'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.byType(FilterRow), findsNothing);
    expect(find.text('Your media. Your player.'), findsNothing);
  });

  testWidgets('shows Continue Watching when recents exist', (tester) async {
    await pumpHome(tester, channels: const [_bbc, _cnn], recents: const [_cnn]);

    expect(find.text('Continue Watching'), findsOneWidget);
    expect(find.text('CNN International'), findsWidgets);
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('Recently Added'), findsNothing);
  });

  testWidgets(
    'QR pairing import shows success and Start Watching does not open player',
    (tester) async {
      final channels = <IPTVChannel>[];
      var openedPlayer = false;
      IPTVChannel? played;

      await pumpHome(
        tester,
        channels: channels,
        onPlayChannel: (channel) {
          openedPlayer = true;
          played = channel;
        },
        pairingFactory: () =>
            _FakePairingServer(resultUrl: 'https://example.com/news.m3u'),
        extraOverrides: [
          addM3uContentSourceProvider.overrideWith((ref, args) async {
            channels.add(_bbc);
            ref.invalidate(iptvChannelsProvider);
          }),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(TvPlaylistUrlDialog), findsOneWidget);
      expect(openedPlayer, isFalse);

      await tester.enterText(
        find.byKey(const ValueKey('tv-home-playlist-label-field')),
        'India news',
      );
      await tester.tap(find.text('Save'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TvPlaylistImportSuccessDialog), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TvPlaylistImportSuccessDialog),
          matching: find.text('India news'),
        ),
        findsOneWidget,
      );
      expect(find.text('Start Watching'), findsOneWidget);
      expect(openedPlayer, isFalse);
      expect(played, isNull);

      await tester.tap(find.text('Start Watching'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(TvPlaylistImportSuccessDialog), findsNothing);
      expect(find.byType(TvHomeScreen), findsOneWidget);
      expect(find.text('Live TV'), findsOneWidget);
      expect(openedPlayer, isFalse);
      expect(played, isNull);
    },
  );

  testWidgets('Start Watching closes import summary and does not open player', (
    tester,
  ) async {
    var openedPlayer = false;
    IPTVChannel? played;

    await pumpHome(
      tester,
      channels: const [_bbc],
      onPlayChannel: (channel) {
        openedPlayer = true;
        played = channel;
      },
    );

    final homeContext = tester.element(find.byType(TvHomeScreen));
    showDialog<void>(
      context: homeContext,
      builder: (_) => const TvPlaylistImportSuccessDialog(
        playlistLabel: 'India news',
        channelCount: 12,
        countries: ['IN'],
        categories: ['News'],
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('India news'), findsOneWidget);
    expect(find.textContaining('12'), findsOneWidget);
    expect(find.text('Start Watching'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Start Watching'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(TvPlaylistImportSuccessDialog), findsNothing);
    expect(find.byType(TvHomeScreen), findsOneWidget);
    expect(find.text('Live TV'), findsOneWidget);
    expect(openedPlayer, isFalse);
    expect(played, isNull);
  });

  testWidgets('URL dialog keeps Save and Cancel above the IME', (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                size: const Size(1280, 720),
                viewInsets: const EdgeInsets.only(bottom: 280),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const TvPlaylistUrlDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveRect = tester.getRect(find.text('Save'));
    final cancelRect = tester.getRect(find.text('Cancel'));
    const keyboardTop = 720.0 - 280.0;
    expect(saveRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(cancelRect.bottom, lessThanOrEqualTo(keyboardTop));
  });

  testWidgets('See all Live TV invokes the Guide callback', (tester) async {
    var sawGuide = false;
    await pumpHome(
      tester,
      channels: const [_bbc],
      onSeeAllLiveTv: () => sawGuide = true,
    );

    await tester.tap(find.text('See all'));
    await tester.pump();
    expect(sawGuide, isTrue);
  });

  testWidgets('channel names are one line with ellipsis', (tester) async {
    await pumpHome(tester, channels: const [_longName]);

    final name = tester.widget<Text>(find.text(_longName.name));
    expect(name.maxLines, 1);
    expect(name.overflow, TextOverflow.ellipsis);
  });
}

class _FakePairingServer implements TvPlaylistPairingServer {
  _FakePairingServer({this.resultUrl, this.never = false});

  final String? resultUrl;
  final bool never;
  final _resultCompleter = Completer<String?>();
  bool stopped = false;

  @override
  Future<Uri> start() async {
    return Uri.parse('http://192.168.1.5:8080/pair/fake-token');
  }

  @override
  Future<String?> get result {
    if (!never && !_resultCompleter.isCompleted) {
      _resultCompleter.complete(resultUrl);
    }
    return _resultCompleter.future;
  }

  @override
  Future<void> cancel() => stop();

  @override
  Future<void> stop() async {
    stopped = true;
    if (!_resultCompleter.isCompleted) _resultCompleter.complete(null);
  }

  @override
  bool get isRunning => !stopped;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
