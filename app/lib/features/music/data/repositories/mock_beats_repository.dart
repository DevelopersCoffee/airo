import 'dart:math';
import '../../domain/models/beats_models.dart';
import '../../domain/repositories/beats_repository.dart';

/// Mock implementation of BeatsRepository for development/testing
/// Uses sample data and simulates network delays
class MockBeatsRepository implements BeatsRepository {
  final List<BeatsTrack> _recentTracks = [];
  final Map<String, BeatsStreamSession> _activeSessions = {};
  final Random _random = Random();

  // Sample tracks for mock search results
  static final List<BeatsTrack> _sampleTracks = [
    const BeatsTrack(
      id: 'yt_fWmYeaveS6o',
      title: 'Demo Track - Beats Test',
      artist: 'Airo Demo',
      thumbnailUrl: 'https://i.ytimg.com/vi/fWmYeaveS6o/hqdefault.jpg',
      duration: Duration(minutes: 3, seconds: 45),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtu.be/fWmYeaveS6o',
    ),
    const BeatsTrack(
      id: 'yt_dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
      thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      duration: Duration(minutes: 3, seconds: 33),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtube.com/watch?v=dQw4w9WgXcQ',
    ),
    const BeatsTrack(
      id: 'yt_9bZkp7q19f0',
      title: 'Gangnam Style',
      artist: 'PSY',
      thumbnailUrl: 'https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg',
      duration: Duration(minutes: 4, seconds: 13),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtube.com/watch?v=9bZkp7q19f0',
    ),
    const BeatsTrack(
      id: 'yt_kJQP7kiw5Fk',
      title: 'Despacito',
      artist: 'Luis Fonsi ft. Daddy Yankee',
      thumbnailUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      duration: Duration(minutes: 4, seconds: 42),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtube.com/watch?v=kJQP7kiw5Fk',
    ),
    const BeatsTrack(
      id: 'yt_JGwWNGJdvx8',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      duration: Duration(minutes: 3, seconds: 53),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtube.com/watch?v=JGwWNGJdvx8',
    ),
  ];

  @override
  Future<BeatsResult<BeatsSearchResult>> searchTracks(
    String query, {
    int limit = 10,
    String? pageToken,
  }) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 300 + _random.nextInt(500)));

    final queryLower = query.toLowerCase();
    final matchingTracks = _sampleTracks
        .where((track) {
          return track.title.toLowerCase().contains(queryLower) ||
              track.artist.toLowerCase().contains(queryLower);
        })
        .take(limit)
        .toList();

    // If no matches, return all sample tracks as suggestions
    final results = matchingTracks.isEmpty
        ? _sampleTracks.take(limit).toList()
        : matchingTracks;

    return BeatsResult.success(
      BeatsSearchResult(
        tracks: results,
        query: query,
        totalResults: results.length,
        hasMore: false,
      ),
    );
  }

  @override
  Future<BeatsResult<BeatsTrack>> resolveUrl(String url) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));

    if (!isValidSourceUrl(url)) {
      return const BeatsResult.failure('Invalid or unsupported URL');
    }

    final videoId = BeatsUrlPatterns.extractYoutubeId(url);
    if (videoId == null) {
      return const BeatsResult.failure('Could not extract video ID from URL');
    }

    // Check if we have this track in samples
    final existingTrack = _sampleTracks.firstWhere(
      (t) => t.sourceUrl?.contains(videoId) == true || t.id.contains(videoId),
      orElse: () => BeatsTrack(
        id: 'yt_$videoId',
        title: 'Resolved Track - $videoId',
        artist: 'Unknown Artist',
        thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        duration: Duration(
          minutes: 3 + _random.nextInt(3),
          seconds: _random.nextInt(60),
        ),
        source: BeatsSource.youtube,
        sourceUrl: url,
        resolvedAt: DateTime.now(),
      ),
    );

    // Add to recent tracks
    if (!_recentTracks.any((t) => t.id == existingTrack.id)) {
      _recentTracks.insert(0, existingTrack);
      if (_recentTracks.length > 50) {
        _recentTracks.removeLast();
      }
    }

    return BeatsResult.success(existingTrack);
  }

  @override
  Future<BeatsResult<BeatsStreamSession>> createStreamSession(
    String trackId,
  ) async {
    // Simulate network delay
    await Future.delayed(Duration(milliseconds: 200 + _random.nextInt(300)));

    final sessionId =
        'session_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(1000)}';
    final now = DateTime.now();

    // For mock, use a sample HLS stream URL
    // In production, this would be the actual HLS manifest from the backend
    final session = BeatsStreamSession(
      sessionId: sessionId,
      trackId: trackId,
      hlsManifestUrl:
          'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8', // Sample HLS stream
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 30)),
    );

    _activeSessions[sessionId] = session;
    return BeatsResult.success(session);
  }

  @override
  Future<BeatsResult<BeatsStreamSession>> refreshStreamSession(
    String sessionId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));

    final existing = _activeSessions[sessionId];
    if (existing == null) {
      return const BeatsResult.failure('Session not found');
    }

    final refreshed = BeatsStreamSession(
      sessionId: sessionId,
      trackId: existing.trackId,
      hlsManifestUrl: existing.hlsManifestUrl,
      createdAt: existing.createdAt,
      expiresAt: DateTime.now().add(const Duration(minutes: 30)),
    );

    _activeSessions[sessionId] = refreshed;
    return BeatsResult.success(refreshed);
  }

  @override
  Future<void> endStreamSession(String sessionId) async {
    _activeSessions.remove(sessionId);
  }

  @override
  bool isValidSourceUrl(String url) => BeatsUrlPatterns.isSupported(url);

  @override
  BeatsSource getSourceFromUrl(String url) => BeatsUrlPatterns.getSource(url);

  @override
  Future<List<BeatsTrack>> getRecentTracks({int limit = 20}) async {
    return _recentTracks.take(limit).toList();
  }

  @override
  Future<void> clearCache() async {
    _recentTracks.clear();
  }
}
