import 'music_service.dart';

/// Simple music track service with sample tracks
class MusicTrackService {
  /// Get sample tracks with direct stream URLs
  static Future<List<MusicTrack>> getSampleTracks() async {
    return [
      MusicTrack(
        id: '1',
        title: 'Blinding Lights',
        artist: 'The Weeknd',
        albumArt: null, // No internet, use null for local fallback
        duration: const Duration(minutes: 3, seconds: 20),
        streamUrl: 'https://songspk.com.se/files/download/id/114064',
      ),
      MusicTrack(
        id: '2',
        title: 'Shape of You',
        artist: 'Ed Sheeran',
        albumArt: null,
        duration: const Duration(minutes: 3, seconds: 53),
        streamUrl: 'https://songspk.com.se/files/download/id/114064',
      ),
      MusicTrack(
        id: '3',
        title: 'Someone You Loved',
        artist: 'Lewis Capaldi',
        albumArt: null,
        duration: const Duration(minutes: 3, seconds: 2),
        streamUrl: 'https://songspk.com.se/files/download/id/114064',
      ),
      MusicTrack(
        id: '4',
        title: 'Perfect',
        artist: 'Ed Sheeran',
        albumArt: null,
        duration: const Duration(minutes: 4, seconds: 23),
        streamUrl: 'https://songspk.com.se/files/download/id/114064',
      ),
      MusicTrack(
        id: '5',
        title: 'Thinking Out Loud',
        artist: 'Ed Sheeran',
        albumArt: null,
        duration: const Duration(minutes: 4, seconds: 41),
        streamUrl: 'https://songspk.com.se/files/download/id/114064',
      ),
    ];
  }
}
