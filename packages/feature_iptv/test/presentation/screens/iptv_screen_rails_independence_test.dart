import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The browse grid must not depend on [railsProvider].
///
/// It used to `ref.watch(railsProvider)` and discard the value, purely to keep
/// the rails warm. Rails are invalidated by every auto-scan availability
/// update, so that read both rebuilt the grid once per probed channel and --
/// because a read forces a dirty provider to flush -- recomputed rails *inside*
/// the grid's build, which tripped "setState() called during build" (issue
/// #1367). The real rails consumers are `browse_screen` and `iptv_tv_screen`.
///
/// Overriding rails with a provider that throws is the cheapest way to assert
/// the independence: if anything in this screen's build reads it, the build
/// fails.
final _channels = [
  const IPTVChannel(
    id: 'c1',
    name: 'Channel One',
    streamUrl: 'https://example.com/c1.m3u8',
    group: 'News',
    category: ChannelCategory.news,
  ),
];

class _SilentStreamingService extends VideoPlayerStreamingService {
  _SilentStreamingService() : super(engine: FakeAiroPlaybackEngine());

  @override
  Future<void> playChannel(IPTVChannel channel) async {}
}

void main() {
  testWidgets('the browse grid renders without ever reading railsProvider', (
    tester,
  ) async {
    // Watching an errored provider returns an AsyncValue rather than throwing,
    // so a thrown override proves nothing. Record whether the provider is
    // built at all instead: it is only built if something reads it.
    var railsWereRead = false;
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          iptvChannelsProvider.overrideWith((ref) async => _channels),
          recentlyWatchedChannelsProvider.overrideWith((ref) async => const []),
          railsProvider.overrideWith((ref) async {
            railsWereRead = true;
            return const <RailResult>[];
          }),
          iptvStreamingServiceProvider.overrideWith((ref) {
            final service = _SilentStreamingService();
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
        child: const MaterialApp(home: IPTVScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Channel One'),
      findsOneWidget,
      reason:
          'channels come from iptvChannelsProvider; a rails failure must '
          'not reach this screen at all',
    );
    expect(
      railsWereRead,
      isFalse,
      reason:
          'rails are invalidated by every auto-scan availability update; a '
          'read here rebuilds the grid per probe and flushes rails inside the '
          'grid build (issue #1367)',
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
