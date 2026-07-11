import "../models/playlist.dart";

abstract class PlaylistProvider {
  String get providerId;
  Future<Playlist> loadPlaylist(String source);
}
