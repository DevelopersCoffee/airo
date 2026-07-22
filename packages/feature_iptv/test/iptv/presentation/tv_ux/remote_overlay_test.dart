import 'package:feature_iptv/presentation/tv_ux/sections/remote_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  const channels = [
    IPTVChannel(id: 'one', name: 'One', streamUrl: 'https://one'),
    IPTVChannel(id: 'two', name: 'Two', streamUrl: 'https://two'),
  ];

  test('random channel selects only from the supplied filtered channels', () {
    final selected = randomFilteredChannel(channels, nextInt: (_) => 1);

    expect(selected, channels.last);
  });

  test('random channel handles empty and one-item filtered lists', () {
    expect(randomFilteredChannel(const [], nextInt: (_) => 0), isNull);
    expect(
      randomFilteredChannel([channels.first], nextInt: (_) => 0),
      channels.first,
    );
  });

  testWidgets('touch controls dispatch and hide after inactivity', (
    tester,
  ) async {
    var next = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RemoteOverlay(
            autoHideDuration: const Duration(seconds: 1),
            onChannelNext: () => next++,
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('remote-channel-next')));
    expect(next, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('remote-channel-next')), findsNothing);
  });

  testWidgets('TV mode does not draw touch buttons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RemoteOverlay(isTv: true))),
    );

    expect(find.byKey(const ValueKey('remote-channel-next')), findsNothing);
    expect(find.byKey(const ValueKey('remote-random')), findsOneWidget);
  });
}
