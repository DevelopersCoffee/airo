import '../../domain/models/beats_models.dart';
import '../../domain/repositories/beats_repository.dart';

/// Mock implementation of BeatsRepository for development/testing
class MockBeatsRepository implements BeatsRepository {
  final List<BeatsTrack> _recentTracks = [];

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
      sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
    ),
    const BeatsTrack(
      id: 'yt_9bZkp7q19f0',
      title: 'Gangnam Style',
      artist: 'PSY',
      thumbnailUrl: 'https://i.ytimg.com/vi/9bZkp7q19f0/hqdefault.jpg',
      duration: Duration(minutes: 4, seconds: 13),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtu.be/9bZkp7q19f0',
    ),
    const BeatsTrack(
      id: 'yt_kJQP7kiw5Fk',
      title: 'Despacito',
      artist: 'Luis Fonsi ft. Daddy Yankee',
      thumbnailUrl: 'https://i.ytimg.com/vi/kJQP7kiw5Fk/hqdefault.jpg',
      duration: Duration(minutes: 4, seconds: 42),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtu.be/kJQP7kiw5Fk',
    ),
    const BeatsTrack(
      id: 'yt_JGwWNGJdvx8',
      title: 'Shape of You',
      artist: 'Ed Sheeran',
      thumbnailUrl: 'https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg',
      duration: Duration(minutes: 3, seconds: 53),
      source: BeatsSource.youtube,
      sourceUrl: 'https://youtu.be/JGwWNGJdvx8',
    ),
  ];

  @override
  Future<BeatsResult<BeatsSearchResult>> searchTracks(
    String query, {
    int limit = 10,
    String? pageToken,
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final lowerQuery = query.toLowerCase();
    final filtered = _sampleTracks
        .where((track) {
          return track.title.toLowerCase().contains(lowerQuery) ||
              track.artist.toLowerCase().contains(lowerQuery);
        })
        .take(limit)
        .toList();

    return BeatsResult.success(
      BeatsSearchResult(tracks: filtered, totalResults: filtered.length),
    );
  }

  @override
  Future<BeatsResult<BeatsTrack>> resolveUrl(String url) async {
    await Future.delayed(const Duration(milliseconds: 300));

    // Handle YouTube URLs
    final videoId = BeatsUrlPatterns.extractYoutubeId(url);
    if (videoId != null) {
      // Check if it's one of our sample tracks
      final existing = _sampleTracks.where(
        (t) => t.sourceUrl?.contains(videoId) ?? false,
      );
      if (existing.isNotEmpty) {
        return BeatsResult.success(existing.first);
      }

      // Create a new track for unknown YouTube URLs
      final track = BeatsTrack(
        id: 'yt_$videoId',
        title: 'YouTube Video ($videoId)',
        artist: 'Unknown Artist',
        thumbnailUrl: 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
        source: BeatsSource.youtube,
        sourceUrl: url,
      );
      return BeatsResult.success(track);
    }

    // Handle SoundCloud URLs
    if (BeatsUrlPatterns.soundcloud.hasMatch(url)) {
      // Extract artist and track from URL
      final match = RegExp(
        r'soundcloud\.com/([\w-]+)/([\w-]+)',
      ).firstMatch(url);
      final artist = match?.group(1) ?? 'Unknown Artist';
      final trackName = match?.group(2) ?? 'Unknown Track';

      final track = BeatsTrack(
        id: 'sc_${artist}_$trackName',
        title: trackName.replaceAll('-', ' '),
        artist: artist.replaceAll('-', ' '),
        source: BeatsSource.soundcloud,
        sourceUrl: url,
      );
      return BeatsResult.success(track);
    }

    return const BeatsResult.failure('Invalid or unsupported URL');
  }

  @override
  Future<BeatsResult<BeatsStreamSession>> createStreamSession(
    String trackId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 200));

    final now = DateTime.now();
    final session = BeatsStreamSession(
      sessionId: 'session_${now.millisecondsSinceEpoch}',
      trackId: trackId,
      hlsManifestUrl: 'https://example.com/hls/$trackId/manifest.m3u8',
      createdAt: now,
      expiresAt: now.add(const Duration(seconds: 60)),
    );

    return BeatsResult.success(session);
  }

  @override
  Future<List<BeatsTrack>> getRecentTracks({int limit = 20}) async {
    return _recentTracks.take(limit).toList();
  }

  @override
  Future<void> clearCache() async {
    _recentTracks.clear();
  }

  @override
  bool isValidSourceUrl(String url) {
    return BeatsUrlPatterns.isSupported(url);
  }
}
