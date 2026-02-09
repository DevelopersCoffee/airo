import '../models/beats_models.dart';

/// Repository interface for Beats audio streaming
abstract class BeatsRepository {
  /// Search for tracks by query
  /// Returns search results with pagination support
  Future<BeatsResult<BeatsSearchResult>> searchTracks(
    String query, {
    int limit = 10,
    String? pageToken,
  });

  /// Resolve a URL (YouTube/SoundCloud) to track metadata
  Future<BeatsResult<BeatsTrack>> resolveUrl(String url);

  /// Create a streaming session for a track
  /// Returns HLS manifest URL with session info
  Future<BeatsResult<BeatsStreamSession>> createStreamSession(String trackId);

  /// Get recently resolved tracks (cached)
  Future<List<BeatsTrack>> getRecentTracks({int limit = 20});

  /// Clear cached tracks
  Future<void> clearCache();

  /// Check if URL is a valid source URL
  bool isValidSourceUrl(String url);
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

  /// Check if URL is a supported source
  static bool isSupported(String url) {
    return youtube.hasMatch(url) || soundcloud.hasMatch(url);
  }

  /// Get source type from URL
  static BeatsSource getSource(String url) {
    if (youtube.hasMatch(url)) return BeatsSource.youtube;
    if (soundcloud.hasMatch(url)) return BeatsSource.soundcloud;
    return BeatsSource.unknown;
  }

  /// Extract YouTube video ID from URL
  static String? extractYoutubeId(String url) {
    // Handle youtu.be format
    final shortMatch = RegExp(r'youtu\.be/([\w-]+)').firstMatch(url);
    if (shortMatch != null) return shortMatch.group(1);

    // Handle youtube.com/watch?v= format
    final watchMatch = RegExp(r'youtube\.com/watch\?v=([\w-]+)').firstMatch(url);
    if (watchMatch != null) return watchMatch.group(1);

    // Handle youtube.com/shorts/ format
    final shortsMatch = RegExp(r'youtube\.com/shorts/([\w-]+)').firstMatch(url);
    if (shortsMatch != null) return shortsMatch.group(1);

    return null;
  }
}

