import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/services/music_service.dart';
import '../../domain/services/music_track_service.dart';

/// Fetch sample music tracks
final musicTracksProvider = FutureProvider<List<MusicTrack>>((ref) async {
  return await MusicTrackService.getSampleTracks();
});

/// Refresh music tracks
final refreshMusicTracksProvider = FutureProvider<void>((ref) async {
  ref.refresh(musicTracksProvider);
});
