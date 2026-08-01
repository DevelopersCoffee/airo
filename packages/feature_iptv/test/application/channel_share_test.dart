import 'package:feature_iptv/application/channel_share.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const link = 'https://developerscoffee.github.io/airo/iptv?v=2';

  test('playable message includes humor, channel name, and link', () {
    final composer = ChannelShareMessageComposer(selectTemplate: (_) => 0);

    final message = composer.compose(
      channelName: '9XM',
      link: Uri.parse(link),
      isPlayable: true,
    );

    expect(message, contains('9XM'));
    expect(message, contains(link));
    expect(message, contains('snacks'));
  });

  test('all approved templates preserve the useful share details', () {
    for (var index = 0; index < 4; index++) {
      final composer = ChannelShareMessageComposer(
        selectTemplate: (_) => index,
      );
      final message = composer.compose(
        channelName: List.filled(120, 'C').join(),
        link: Uri.parse(link),
        isPlayable: true,
      );

      expect(
        message,
        contains(List.filled(120, 'C').join()),
        reason: 'template $index',
      );
      expect(message, contains(link), reason: 'template $index');
      expect(
        message.substring(0, message.indexOf(link)).length,
        lessThanOrEqualTo(180),
      );
    }
  });

  test('reference-only message is clear and non-humorous', () {
    const composer = ChannelShareMessageComposer();

    final message = composer.compose(
      channelName: 'Private Channel',
      link: Uri.parse(link),
      isPlayable: false,
    );

    expect(message, contains('same playlist'));
    expect(message, isNot(contains('snacks')));
  });
}
