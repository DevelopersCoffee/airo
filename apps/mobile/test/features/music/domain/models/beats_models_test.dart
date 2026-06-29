import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/music/domain/models/beats_models.dart';
import 'package:airo_app/features/music/domain/repositories/beats_repository.dart';

void main() {
  group('BeatsTrack', () {
    test('creates track with required fields', () {
      const track = BeatsTrack(
        id: 'yt_abc123',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(minutes: 3, seconds: 30),
        source: BeatsSource.youtube,
      );

      expect(track.id, 'yt_abc123');
      expect(track.title, 'Test Song');
      expect(track.artist, 'Test Artist');
      expect(track.duration, const Duration(minutes: 3, seconds: 30));
      expect(track.source, BeatsSource.youtube);
      expect(track.thumbnailUrl, isNull);
      expect(track.sourceUrl, isNull);
      expect(track.streamUrl, isNull);
    });

    test('creates track with all fields', () {
      const track = BeatsTrack(
        id: 'sc_xyz789',
        title: 'Full Track',
        artist: 'Full Artist',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        duration: Duration(minutes: 4),
        source: BeatsSource.soundcloud,
        sourceUrl: 'https://soundcloud.com/track',
        streamUrl: 'https://stream.example.com/hls/manifest.m3u8',
      );

      expect(track.thumbnailUrl, 'https://example.com/thumb.jpg');
      expect(track.sourceUrl, 'https://soundcloud.com/track');
      expect(track.streamUrl, 'https://stream.example.com/hls/manifest.m3u8');
    });

    test('equality works correctly', () {
      const track1 = BeatsTrack(
        id: 'yt_abc123',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(minutes: 3),
        source: BeatsSource.youtube,
      );

      const track2 = BeatsTrack(
        id: 'yt_abc123',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(minutes: 3),
        source: BeatsSource.youtube,
      );

      const track3 = BeatsTrack(
        id: 'yt_different',
        title: 'Test Song',
        artist: 'Test Artist',
        duration: Duration(minutes: 3),
        source: BeatsSource.youtube,
      );

      expect(track1, equals(track2));
      expect(track1, isNot(equals(track3)));
    });

    test('copyWith creates new instance with updated fields', () {
      const original = BeatsTrack(
        id: 'yt_abc123',
        title: 'Original Title',
        artist: 'Original Artist',
        duration: Duration(minutes: 3),
        source: BeatsSource.youtube,
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        streamUrl: 'https://stream.example.com/hls/manifest.m3u8',
      );

      expect(updated.id, original.id);
      expect(updated.title, 'Updated Title');
      expect(updated.artist, original.artist);
      expect(updated.streamUrl, 'https://stream.example.com/hls/manifest.m3u8');
    });
  });

  group('BeatsSearchResult', () {
    test('creates search result with tracks', () {
      const tracks = [
        BeatsTrack(
          id: 'yt_1',
          title: 'Track 1',
          artist: 'Artist 1',
          duration: Duration(minutes: 3),
          source: BeatsSource.youtube,
        ),
        BeatsTrack(
          id: 'yt_2',
          title: 'Track 2',
          artist: 'Artist 2',
          duration: Duration(minutes: 4),
          source: BeatsSource.youtube,
        ),
      ];

      const result = BeatsSearchResult(
        tracks: tracks,
        nextPageToken: 'next_token',
        totalResults: 2,
      );

      expect(result.tracks.length, 2);
      expect(result.totalResults, 2);
      expect(result.nextPageToken, 'next_token');
    });

    test('empty result has no tracks', () {
      const result = BeatsSearchResult(tracks: []);

      expect(result.tracks, isEmpty);
      expect(result.nextPageToken, isNull);
    });
  });

  group('BeatsStreamSession', () {
    test('creates stream session with required fields', () {
      final createdAt = DateTime.now();
      final expiresAt = createdAt.add(const Duration(minutes: 2));
      final session = BeatsStreamSession(
        sessionId: 'session_123',
        trackId: 'yt_abc123',
        hlsManifestUrl: 'https://stream.example.com/hls/manifest.m3u8',
        createdAt: createdAt,
        expiresAt: expiresAt,
      );

      expect(session.sessionId, 'session_123');
      expect(session.trackId, 'yt_abc123');
      expect(
        session.hlsManifestUrl,
        'https://stream.example.com/hls/manifest.m3u8',
      );
      expect(session.createdAt, createdAt);
      expect(session.expiresAt, expiresAt);
    });

    test('isExpired returns true for past expiry', () {
      final session = BeatsStreamSession(
        sessionId: 'session_123',
        trackId: 'yt_abc123',
        hlsManifestUrl: 'https://stream.example.com/hls/manifest.m3u8',
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(session.isExpired, isTrue);
    });

    test('isExpired returns false for future expiry', () {
      final session = BeatsStreamSession(
        sessionId: 'session_123',
        trackId: 'yt_abc123',
        hlsManifestUrl: 'https://stream.example.com/hls/manifest.m3u8',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      expect(session.isExpired, isFalse);
    });
  });

  group('BeatsSearchUiState', () {
    test('initial state is idle with no results', () {
      const state = BeatsSearchUiState();

      expect(state.state, BeatsSearchState.idle);
      expect(state.results, isEmpty);
      expect(state.errorMessage, isNull);
      expect(state.query, isEmpty);
    });

    test('copyWith updates state correctly', () {
      const initial = BeatsSearchUiState();
      final searching = initial.copyWith(
        state: BeatsSearchState.searching,
        query: 'test query',
      );

      expect(searching.state, BeatsSearchState.searching);
      expect(searching.query, 'test query');
      expect(searching.results, isEmpty);
    });
  });

  group('BeatsUrlPatterns', () {
    group('YouTube URL detection', () {
      test('detects standard youtube.com/watch URLs', () {
        expect(
          BeatsUrlPatterns.isSupported(
            'https://www.youtube.com/watch?v=fWmYeaveS6o',
          ),
          isTrue,
        );
        expect(
          BeatsUrlPatterns.isSupported(
            'https://youtube.com/watch?v=fWmYeaveS6o',
          ),
          isTrue,
        );
        expect(
          BeatsUrlPatterns.isSupported(
            'http://www.youtube.com/watch?v=fWmYeaveS6o',
          ),
          isTrue,
        );
      });

      test('detects youtu.be short URLs', () {
        expect(
          BeatsUrlPatterns.isSupported('https://youtu.be/fWmYeaveS6o'),
          isTrue,
        );
        expect(
          BeatsUrlPatterns.isSupported('https://youtu.be/fWmYeaveS6o?list=LL'),
          isTrue,
        );
      });

      test('detects youtube shorts URLs', () {
        expect(
          BeatsUrlPatterns.isSupported('https://youtube.com/shorts/abc123'),
          isTrue,
        );
        expect(
          BeatsUrlPatterns.isSupported('https://www.youtube.com/shorts/xyz789'),
          isTrue,
        );
      });

      test('returns youtube source for YouTube URLs', () {
        expect(
          BeatsUrlPatterns.getSource('https://youtu.be/fWmYeaveS6o'),
          BeatsSource.youtube,
        );
        expect(
          BeatsUrlPatterns.getSource('https://youtube.com/watch?v=abc'),
          BeatsSource.youtube,
        );
      });

      test('extracts YouTube video ID correctly', () {
        expect(
          BeatsUrlPatterns.extractYoutubeId('https://youtu.be/fWmYeaveS6o'),
          'fWmYeaveS6o',
        );
        expect(
          BeatsUrlPatterns.extractYoutubeId(
            'https://youtube.com/watch?v=abc123',
          ),
          'abc123',
        );
        expect(
          BeatsUrlPatterns.extractYoutubeId('https://youtu.be/xyz789?list=LL'),
          'xyz789',
        );
      });
    });

    group('SoundCloud URL detection', () {
      test('detects SoundCloud URLs', () {
        expect(
          BeatsUrlPatterns.isSupported('https://soundcloud.com/artist/track'),
          isTrue,
        );
        expect(
          BeatsUrlPatterns.isSupported(
            'https://www.soundcloud.com/artist/track',
          ),
          isTrue,
        );
      });

      test('returns soundcloud source for SoundCloud URLs', () {
        expect(
          BeatsUrlPatterns.getSource('https://soundcloud.com/artist/track'),
          BeatsSource.soundcloud,
        );
      });
    });

    group('Unsupported URLs', () {
      test('returns false for unsupported URLs', () {
        expect(
          BeatsUrlPatterns.isSupported('https://spotify.com/track/abc'),
          isFalse,
        );
        expect(BeatsUrlPatterns.isSupported('https://example.com'), isFalse);
        expect(BeatsUrlPatterns.isSupported('not a url'), isFalse);
      });

      test('returns unknown source for unsupported URLs', () {
        expect(
          BeatsUrlPatterns.getSource('https://spotify.com/track/abc'),
          BeatsSource.unknown,
        );
        expect(BeatsUrlPatterns.getSource('random text'), BeatsSource.unknown);
      });

      test('returns null for non-YouTube URL ID extraction', () {
        expect(
          BeatsUrlPatterns.extractYoutubeId('https://soundcloud.com/track'),
          isNull,
        );
        expect(BeatsUrlPatterns.extractYoutubeId('not a url'), isNull);
      });
    });
  });
}
