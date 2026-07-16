import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  final adapter = M3uVodAdapter();

  test('a channel categorized as movies is extracted as a VodItem', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example Movie',
      url: 'https://example.com/movie.mp4',
      group: 'Movies',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
    expect(items.single.id, channel.id);
    expect(items.single.title, 'Example Movie');
    expect(items.single.streamUrl, channel.streamUrl);
    expect(items.single.kind, VodContentKind.movie);
  });

  test('a channel whose group contains "VOD" is extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Some Title',
      url: 'https://example.com/vod-item.mp4',
      group: 'US VOD',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
  });

  test('a channel whose group contains "Series" is extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example Show S01E01',
      url: 'https://example.com/series/1.mp4',
      group: 'TV Series',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, hasLength(1));
  });

  test('a live news channel is not extracted', () {
    final channel = IPTVChannel.fromM3U(
      name: 'Example News',
      url: 'https://example.com/news.m3u8',
      group: 'News',
    );

    final items = adapter.extractVodItems([channel]);

    expect(items, isEmpty);
  });

  test('empty source list yields empty result', () {
    expect(adapter.extractVodItems(const []), isEmpty);
  });
}
