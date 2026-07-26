import 'package:feature_iptv/application/iptv_deep_link.dart';
import 'package:feature_iptv/application/providers/channel_filters_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('channel-only link round-trips without filter parameters', () {
    const intent = IptvDeepLinkIntent(channelId: 'news/local');

    final uri = intent.toUri();
    final parsed = IptvDeepLinkIntent.tryParse(uri);

    expect(uri.toString(), contains('/airo/iptv?'));
    expect(uri.queryParameters, {'v': '1', 'channel': 'news/local'});
    expect(parsed?.channelId, 'news/local');
    expect(parsed?.filters, const ChannelFilters());
  });

  test('channel and active filters round-trip exactly', () {
    const filters = ChannelFilters(
      search: 'evening news',
      category: 'News',
      country: 'in',
      language: 'Hindi',
    );
    const intent = IptvDeepLinkIntent(
      channelId: 'news.local',
      filters: filters,
    );

    final parsed = IptvDeepLinkIntent.tryParse(intent.toUri());

    expect(parsed?.channelId, intent.channelId);
    expect(parsed?.filters, filters);
  });

  test('internal and custom-scheme routes parse through the same contract', () {
    for (final uri in [
      Uri.parse('/iptv?channel=one&country=in'),
      Uri.parse('airo://iptv?channel=one&country=in'),
    ]) {
      final parsed = IptvDeepLinkIntent.tryParse(uri);
      expect(parsed?.channelId, 'one');
      expect(parsed?.filters.country, 'in');
    }
  });

  test('malformed, unsupported, and oversized links are rejected safely', () {
    expect(
      IptvDeepLinkIntent.tryParse(
        Uri.parse('https://example.com/airo/iptv?channel=one'),
      ),
      isNull,
    );
    expect(
      IptvDeepLinkIntent.tryParse(Uri.parse('/iptv?v=2&channel=one')),
      isNull,
    );
    expect(IptvDeepLinkIntent.tryParse(Uri.parse('/iptv?channel=')), isNull);
    expect(
      IptvDeepLinkIntent.tryParse(
        Uri.parse('/iptv?channel=${List.filled(257, 'x').join()}'),
      ),
      isNull,
    );
  });

  test('generated links never include stream or credential material', () {
    const intent = IptvDeepLinkIntent(
      channelId: 'safe-id',
      filters: ChannelFilters(search: 'sports'),
    );

    final link = intent.toUri().toString();

    expect(link, isNot(contains('stream')));
    expect(link, isNot(contains('token')));
    expect(link, isNot(contains('password')));
  });
}
