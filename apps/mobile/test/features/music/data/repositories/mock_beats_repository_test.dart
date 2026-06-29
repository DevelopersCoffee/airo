import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/music/data/repositories/mock_beats_repository.dart';
import 'package:airo_app/features/music/domain/models/beats_models.dart';

void main() {
  late MockBeatsRepository repository;

  setUp(() {
    repository = MockBeatsRepository();
  });

  group('MockBeatsRepository', () {
    group('searchTracks', () {
      test('returns tracks matching query', () async {
        final result = await repository.searchTracks('demo');

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.tracks, isNotEmpty);
      });

      test('returns empty list for non-matching query', () async {
        final result = await repository.searchTracks('xyznonexistent123');

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.tracks, isEmpty);
      });

      test('respects limit parameter', () async {
        final result = await repository.searchTracks('track', limit: 2);

        expect(result.isSuccess, isTrue);
        expect(result.data!.tracks.length, lessThanOrEqualTo(2));
      });

      test('search is case insensitive', () async {
        final lowerResult = await repository.searchTracks('demo');
        final upperResult = await repository.searchTracks('DEMO');

        expect(lowerResult.isSuccess, isTrue);
        expect(upperResult.isSuccess, isTrue);
        expect(
          lowerResult.data!.tracks.length,
          upperResult.data!.tracks.length,
        );
      });
    });

    group('resolveUrl', () {
      test('resolves YouTube URL successfully', () async {
        final result = await repository.resolveUrl(
          'https://youtu.be/fWmYeaveS6o',
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.source, BeatsSource.youtube);
      });

      test('resolves SoundCloud URL successfully', () async {
        final result = await repository.resolveUrl(
          'https://soundcloud.com/artist/track',
        );

        expect(result.isSuccess, isTrue);
        expect(result.data, isNotNull);
        expect(result.data!.source, BeatsSource.soundcloud);
      });

      test('returns error for unsupported URL', () async {
        final result = await repository.resolveUrl(
          'https://spotify.com/track/abc',
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });
    });

    group('createStreamSession', () {
      test('creates session for valid track ID', () async {
        // First search to get a valid track ID
        final searchResult = await repository.searchTracks('demo');
        expect(searchResult.isSuccess, isTrue);
        expect(searchResult.data!.tracks, isNotEmpty);

        final trackId = searchResult.data!.tracks.first.id;
        final sessionResult = await repository.createStreamSession(trackId);

        expect(sessionResult.isSuccess, isTrue);
        expect(sessionResult.data, isNotNull);
        expect(sessionResult.data!.trackId, trackId);
        expect(sessionResult.data!.hlsManifestUrl, isNotEmpty);
        expect(sessionResult.data!.isExpired, isFalse);
      });

      test('session has valid expiration time', () async {
        final searchResult = await repository.searchTracks('demo');
        final trackId = searchResult.data!.tracks.first.id;
        final sessionResult = await repository.createStreamSession(trackId);

        expect(sessionResult.isSuccess, isTrue);
        final session = sessionResult.data!;

        // Session should expire in the future
        expect(session.expiresAt.isAfter(DateTime.now()), isTrue);
        // Session should have been created recently
        expect(
          session.createdAt.difference(DateTime.now()).inSeconds.abs(),
          lessThan(5),
        );
      });
    });

    group('getRecentTracks', () {
      test('returns list of recent tracks', () async {
        final tracks = await repository.getRecentTracks();

        expect(tracks, isA<List<BeatsTrack>>());
        // Mock repository may return empty or sample tracks
      });
    });

    group('clearCache', () {
      test('clears cache without error', () async {
        // Should not throw
        await repository.clearCache();

        final tracks = await repository.getRecentTracks();
        expect(tracks, isEmpty);
      });
    });
  });
}
