import 'package:feature_iptv/presentation/tv_ux/sections/remote_overlay.dart';
import 'package:core_ui/core_ui.dart';
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

  test('hardware channel keys map to filtered-list navigation', () {
    var next = 0;
    var previous = 0;

    expect(
      handleRemoteOverlayInput(
        TvInputKey.channelUp,
        onChannelNext: () => next++,
        onChannelPrevious: () => previous++,
      ),
      TvInputResult.handled,
    );
    expect(
      handleRemoteOverlayInput(
        TvInputKey.channelDown,
        onChannelNext: () => next++,
        onChannelPrevious: () => previous++,
      ),
      TvInputResult.handled,
    );
    expect(next, 1);
    expect(previous, 1);
    expect(
      handleRemoteOverlayInput(TvInputKey.playPause),
      TvInputResult.notHandled,
    );
  });
}
