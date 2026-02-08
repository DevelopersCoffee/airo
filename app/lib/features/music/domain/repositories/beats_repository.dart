import '../models/beats_models.dart';

/// Result wrapper for Beats operations
class BeatsResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  const BeatsResult.success(this.data) : error = null, isSuccess = true;

  const BeatsResult.failure(this.error) : data = null, isSuccess = false;
}

/// Repository interface for Beats track resolution and streaming
abstract class BeatsRepository {
  /// Search for tracks by query string
  /// Returns a list of matching tracks with metadata
  Future<BeatsResult<BeatsSearchResult>> searchTracks(
    String query, {
    int limit = 10,
    String? pageToken,
  });

  /// Resolve a URL (YouTube, SoundCloud) to track metadata
  /// Does NOT create a stream - just resolves metadata
  Future<BeatsResult<BeatsTrack>> resolveUrl(String url);

  /// Create a stream session for a track
  /// Returns HLS manifest URL for playback
  Future<BeatsResult<BeatsStreamSession>> createStreamSession(String trackId);

  /// Refresh an expiring stream session
  Future<BeatsResult<BeatsStreamSession>> refreshStreamSession(
    String sessionId,
  );

  /// End a stream session (cleanup)
  Future<void> endStreamSession(String sessionId);

  /// Check if a URL is a valid Beats source (YouTube, SoundCloud)
  bool isValidSourceUrl(String url);

  /// Extract source type from URL
  BeatsSource getSourceFromUrl(String url);

  /// Get recently resolved tracks (cached)
  Future<List<BeatsTrack>> getRecentTracks({int limit = 20});

  /// Clear cached tracks
  Future<void> clearCache();
}

/// URL patterns for source detection
class BeatsUrlPatterns {
  static final RegExp youtube = RegExp(
    r'^(https?://)?(www\.)?(youtube\.com/watch\?v=|youtu\.be/|youtube\.com/shorts/)[\w-]+',
    caseSensitive: false,
  );

  static final RegExp soundcloud = RegExp(
    r'^(https?://)?(www\.)?soundcloud\.com/[\w-]+/[\w-]+',
    caseSensitive: false,
  );

  static final RegExp youtubePlaylist = RegExp(
    r'^(https?://)?(www\.)?youtube\.com/playlist\?list=[\w-]+',
    caseSensitive: false,
  );

  /// Check if URL matches any supported source
  static bool isSupported(String url) {
    return youtube.hasMatch(url) || soundcloud.hasMatch(url);
  }

  /// Get source type from URL
  static BeatsSource getSource(String url) {
    if (youtube.hasMatch(url) || youtubePlaylist.hasMatch(url)) {
      return BeatsSource.youtube;
    }
    if (soundcloud.hasMatch(url)) {
      return BeatsSource.soundcloud;
    }
    return BeatsSource.unknown;
  }

  /// Extract video ID from YouTube URL
  static String? extractYoutubeId(String url) {
    // Handle youtu.be format
    final shortMatch = RegExp(r'youtu\.be/([\w-]+)').firstMatch(url);
    if (shortMatch != null) {
      return shortMatch.group(1);
    }

    // Handle youtube.com/watch?v= format
    final watchMatch = RegExp(
      r'youtube\.com/watch\?v=([\w-]+)',
    ).firstMatch(url);
    if (watchMatch != null) {
      return watchMatch.group(1);
    }

    // Handle youtube.com/shorts/ format
    final shortsMatch = RegExp(r'youtube\.com/shorts/([\w-]+)').firstMatch(url);
    if (shortsMatch != null) {
      return shortsMatch.group(1);
    }

    return null;
  }
}
