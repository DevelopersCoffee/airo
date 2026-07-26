import 'package:core_media_data/core_media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 7, 27, 18);
  final profile = MediaRankingProfile.fromEvents([
    MediaViewingEvent(
      titleId: 'unfinished',
      genres: const {'Comedy'},
      provider: 'Provider A',
      language: 'English',
      completionPermille: 500,
      watchedAt: now.subtract(const Duration(days: 2)),
    ),
    MediaViewingEvent(
      titleId: 'finished',
      genres: const {'Drama'},
      provider: 'Provider B',
      language: 'Hindi',
      completionPermille: 950,
      watchedAt: now.subtract(const Duration(days: 20)),
    ),
  ]);

  test('frozen inputs produce identical auditable ranking', () async {
    final request = MediaRankingRequest(
      candidates: [
        MediaRankingCandidate(
          id: 'finished',
          title: 'Zed',
          genres: const {'Drama'},
          provider: 'Provider B',
          language: 'Hindi',
        ),
        MediaRankingCandidate(
          id: 'unfinished',
          title: 'Alpha',
          genres: const {'Comedy'},
          provider: 'Provider A',
          language: 'English',
          preferredTimeBuckets: const {MediaTimeBucket.evening},
          supportedDeviceClasses: const {'tv'},
        ),
      ],
      profile: profile,
      now: now,
      timeBucket: MediaTimeBucket.evening,
      deviceClass: 'TV',
    );
    const executor = DeterministicMediaRankingExecutor();

    final first = await executor.rank(request);
    final second = await executor.rank(request);

    expect(first, second);
    expect(first.first.candidate.id, 'unfinished');
    final points = {
      for (final item in first.first.contributions) item.ruleId: item.points,
    };
    expect(points['completion_v1'], 150);
    expect(points['recency_v1'], 40);
    expect(points['time_bucket_v1'], 50);
    expect(points['device_fit_v1'], 25);
    expect(
      first.last.contributions
          .singleWhere((item) => item.ruleId == 'completion_v1')
          .points,
      -5000,
    );
    expect(
      first.first.contributions.map((item) => item.ruleId),
      containsAll({
        'genre_affinity_v1',
        'provider_affinity_v1',
        'language_affinity_v1',
        'completion_v1',
        'recency_v1',
        'time_bucket_v1',
        'device_fit_v1',
      }),
    );
  });

  test('neutral ranking has stable title and ID tie breaks', () async {
    final result = await const DeterministicMediaRankingExecutor().rank(
      MediaRankingRequest(
        candidates: [
          MediaRankingCandidate(
            id: 'z',
            title: 'Same',
            genres: const {},
            provider: '',
            language: '',
          ),
          MediaRankingCandidate(
            id: 'a',
            title: 'Same',
            genres: const {},
            provider: '',
            language: '',
          ),
          MediaRankingCandidate(
            id: 'b',
            title: 'Alpha',
            genres: const {},
            provider: '',
            language: '',
          ),
        ],
        profile: MediaRankingProfile.fromEvents(const []),
        now: now,
        timeBucket: MediaTimeBucket.evening,
        deviceClass: 'tv',
      ),
    );

    expect(result.map((item) => item.candidate.id), ['b', 'a', 'z']);
    expect(result.every((item) => item.score == 0), isTrue);
  });

  test('synthetic 600-title host fixture ranks under 50ms', () async {
    final candidates = [
      for (var index = 0; index < 600; index++)
        MediaRankingCandidate(
          id: 'title-$index',
          title: 'Title ${index.toString().padLeft(3, '0')}',
          genres: {index.isEven ? 'Comedy' : 'Drama'},
          provider: index.isEven ? 'Provider A' : 'Provider B',
          language: index.isEven ? 'English' : 'Hindi',
          preferredTimeBuckets: const {MediaTimeBucket.evening},
          supportedDeviceClasses: const {'tv'},
        ),
    ];
    final stopwatch = Stopwatch()..start();

    final result = await const DeterministicMediaRankingExecutor().rank(
      MediaRankingRequest(
        candidates: candidates,
        profile: profile,
        now: now,
        timeBucket: MediaTimeBucket.evening,
        deviceClass: 'tv',
      ),
    );
    stopwatch.stop();

    expect(result, hasLength(600));
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 50)));
  });
}
