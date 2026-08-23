import 'dart:typed_data';

import 'package:airo_app/features/iptv/iptv_feature_module.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingStreamingService extends VideoPlayerStreamingService {
  _RecordingStreamingService() : super(engine: FakeAiroPlaybackEngine());
}

class _FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<String?> getTemporaryPath() async => '/tmp';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  setUp(() {
    PathProviderPlatform.instance = _FakePathProviderPlatform();
  });

  List<Override> iptvOverrides(SharedPreferences prefs) => [
    sharedPreferencesProvider.overrideWithValue(prefs),
    iptvChannelsProvider.overrideWith((ref) async => const []),
    recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
    streamingStateProvider.overrideWith(
      (ref) => Stream.value(
        StreamingState(playbackState: PlaybackState.idle, isLiveStream: true),
      ),
    ),
    iptvStreamingServiceProvider.overrideWith((ref) {
      final service = _RecordingStreamingService();
      ref.onDispose(service.dispose);
      return service;
    }),
  ];

  Future<void> pumpIptvRouter(
    WidgetTester tester, {
    required List<RouteBase> routes,
    required String initialLocation,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(routes: routes, initialLocation: initialLocation);

    await tester.pumpWidget(
      ProviderScope(
        overrides: iptvOverrides(prefs),
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, null);
  });

  test('IPTV module exposes mobile and TV route tables', () {
    final module = IptvFeatureModule();

    expect(module.id, 'iptv');
    expect(module.supportedShells, {ShellId.mobile, ShellId.tv});

    final mobileRoutes = module.routesFor(ShellId.mobile);
    expect(mobileRoutes.whereType<GoRoute>().map((route) => route.path), [
      '/iptv',
      '/iptv/player',
      '/vod',
    ]);

    final tvRoutes = module.routesFor(ShellId.tv);
    expect(tvRoutes.whereType<GoRoute>().map((route) => route.path), [
      '/iptv',
      '/iptv/player',
    ]);
  });

  testWidgets('mobile IPTV route wires share callbacks', (tester) async {
    final module = IptvFeatureModule();
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(shareChannel, (call) async {
          calls.add(call);
          return 'success';
        });

    await pumpIptvRouter(
      tester,
      routes: module.routesFor(ShellId.mobile),
      initialLocation: '/iptv',
    );

    final iptvScreen = tester.widget<IPTVScreen>(find.byType(IPTVScreen));
    expect(iptvScreen.onShareVideoFrame, isNotNull);
    expect(iptvScreen.onPickLocalMediaForTv, isNull);

    await tester.runAsync(() async {
      await iptvScreen.onShareVideoFrame!(
        Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]),
      );
    });
    expect(calls.map((call) => call.method), ['share']);
  });

  testWidgets('mobile IPTV route opens VOD and player routes', (tester) async {
    final module = IptvFeatureModule();

    await pumpIptvRouter(
      tester,
      routes: module.routesFor(ShellId.mobile),
      initialLocation: '/iptv',
    );

    final iptvScreen = tester.widget<IPTVScreen>(find.byType(IPTVScreen));
    iptvScreen.onOpenVod?.call();
    await tester.pumpAndSettle();
    expect(find.byType(VodScreen), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(VodScreen)));
    router.go('/iptv/player?channelId=news-1');
    await tester.pumpAndSettle();

    final playerScreen = tester.widget<IPTVScreen>(find.byType(IPTVScreen));
    expect(playerScreen.key, const ValueKey<String>('news-1'));
  });

  testWidgets('TV IPTV routes build screens and honor channel keys', (
    tester,
  ) async {
    final module = IptvFeatureModule();

    await pumpIptvRouter(
      tester,
      routes: module.routesFor(ShellId.tv),
      initialLocation: '/iptv',
    );

    expect(find.byType(IPTVScreen), findsOneWidget);

    final router = GoRouter.of(tester.element(find.byType(IPTVScreen)));
    router.go('/iptv/player?channelId=stream-news');
    await tester.pumpAndSettle();

    final iptvScreen = tester.widget<IPTVScreen>(find.byType(IPTVScreen));
    expect(iptvScreen.key, const ValueKey<String>('stream-news'));
  });
}
