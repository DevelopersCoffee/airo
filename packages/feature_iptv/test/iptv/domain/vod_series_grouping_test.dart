import 'package:feature_iptv/domain/vod_series_grouping.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('VodSeriesGrouper.applySeriesRef', () {
    final grouper = VodSeriesGrouper();

    test('parses "Show Name S01E02"', () {
      const item = VodItem(
        id: '1',
        title: 'Example Show S01E02',
        streamUrl: 'https://example.com/1.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.kind, VodContentKind.episode);
      expect(result.seriesRef?.seriesTitle, 'Example Show');
      expect(result.seriesRef?.seriesId, 'example-show');
      expect(result.seriesRef?.seasonNumber, 1);
      expect(result.seriesRef?.episodeNumber, 2);
    });

    test('parses single-digit "Show Name S1E2"', () {
      const item = VodItem(
        id: '2',
        title: 'Example Show S1E2',
        streamUrl: 'https://example.com/2.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.seriesRef?.seasonNumber, 1);
      expect(result.seriesRef?.episodeNumber, 2);
    });

    test('parses "Show Name - S01E02 - Episode Title", trimming trailing punctuation', () {
      const item = VodItem(
        id: '3',
        title: 'Example Show - S01E02 - The Big One',
        streamUrl: 'https://example.com/3.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.seriesRef?.seriesTitle, 'Example Show');
    });

    test('a title with no S00E00 pattern stays a movie with no seriesRef', () {
      const item = VodItem(
        id: '4',
        title: 'Example Movie',
        streamUrl: 'https://example.com/4.mp4',
        group: 'Movies',
        kind: VodContentKind.movie,
      );

      final result = grouper.applySeriesRef(item);

      expect(result.kind, VodContentKind.movie);
      expect(result.seriesRef, isNull);
      expect(result.title, 'Example Movie');
    });

    test('same series title always yields the same seriesId', () {
      const a = VodItem(
        id: '5',
        title: 'Example Show S01E01',
        streamUrl: 'https://example.com/5.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );
      const b = VodItem(
        id: '6',
        title: 'Example Show S02E10',
        streamUrl: 'https://example.com/6.mp4',
        group: 'Series',
        kind: VodContentKind.movie,
      );

      final resultA = grouper.applySeriesRef(a);
      final resultB = grouper.applySeriesRef(b);

      expect(resultA.seriesRef?.seriesId, resultB.seriesRef?.seriesId);
    });
  });

  group('groupVodItemsBySeries', () {
    test('partitions episodes into series groups and leaves movies standalone', () {
      final items = [
        const VodItem(
          id: '1',
          title: 'Example Show S01E01',
          streamUrl: 'https://example.com/1.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ),
        const VodItem(
          id: '2',
          title: 'Example Show S01E02',
          streamUrl: 'https://example.com/2.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 2,
          ),
        ),
        const VodItem(
          id: '3',
          title: 'Example Movie',
          streamUrl: 'https://example.com/3.mp4',
          group: 'Movies',
          kind: VodContentKind.movie,
        ),
      ];

      final groups = groupVodItemsBySeries(items);

      expect(groups, hasLength(1));
      expect(groups.single.seriesId, 'example-show');
      expect(groups.single.episodes, hasLength(2));
    });

    test('episodes within a group are sorted by season then episode number', () {
      final items = [
        const VodItem(
          id: '1',
          title: 'Example Show S01E02',
          streamUrl: 'https://example.com/1.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 2,
          ),
        ),
        const VodItem(
          id: '2',
          title: 'Example Show S01E01',
          streamUrl: 'https://example.com/2.mp4',
          group: 'Series',
          kind: VodContentKind.episode,
          seriesRef: VodSeriesRef(
            seriesId: 'example-show',
            seriesTitle: 'Example Show',
            seasonNumber: 1,
            episodeNumber: 1,
          ),
        ),
      ];

      final groups = groupVodItemsBySeries(items);

      expect(groups.single.episodes.map((e) => e.id), ['2', '1']);
    });

    test('empty input yields empty output', () {
      expect(groupVodItemsBySeries(const []), isEmpty);
    });
  });
}
