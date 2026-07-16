import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('VodSeriesRef', () {
    test('equality is field-based', () {
      const a = VodSeriesRef(
        seriesId: 'series-1',
        seriesTitle: 'Example Show',
        seasonNumber: 1,
        episodeNumber: 2,
      );
      const b = VodSeriesRef(
        seriesId: 'series-1',
        seriesTitle: 'Example Show',
        seasonNumber: 1,
        episodeNumber: 2,
      );
      expect(a, b);
    });
  });

  group('VodItem', () {
    test('a movie has no seriesRef', () {
      const item = VodItem(
        id: 'xtream-vod-1',
        title: 'Example Movie',
        streamUrl: 'https://example.com/movie/1.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      expect(item.kind, VodContentKind.movie);
      expect(item.seriesRef, isNull);
    });

    test('an episode carries its seriesRef', () {
      const item = VodItem(
        id: 'xtream-vod-2',
        title: 'Example Show S01E02',
        streamUrl: 'https://example.com/series/2.mp4',
        group: 'Series',
        kind: VodContentKind.episode,
        seriesRef: VodSeriesRef(
          seriesId: 'example-show',
          seriesTitle: 'Example Show',
          seasonNumber: 1,
          episodeNumber: 2,
        ),
      );

      expect(item.seriesRef?.seasonNumber, 1);
      expect(item.seriesRef?.episodeNumber, 2);
    });

    test('toJson/fromJson round-trips all fields', () {
      const item = VodItem(
        id: 'xtream-vod-3',
        title: 'Example Show S02E05',
        streamUrl: 'https://example.com/series/5.mp4',
        posterUrl: 'https://example.com/poster.jpg',
        group: 'Series',
        kind: VodContentKind.episode,
        containerExtension: 'mp4',
        seriesRef: VodSeriesRef(
          seriesId: 'example-show',
          seriesTitle: 'Example Show',
          seasonNumber: 2,
          episodeNumber: 5,
        ),
      );

      final decoded = VodItem.fromJson(item.toJson());

      expect(decoded, item);
    });

    test('toJson/fromJson round-trips a movie with no seriesRef', () {
      const item = VodItem(
        id: 'm3u-vod-1',
        title: 'Example Movie',
        streamUrl: 'https://example.com/movie.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      final decoded = VodItem.fromJson(item.toJson());

      expect(decoded, item);
    });
  });
}
