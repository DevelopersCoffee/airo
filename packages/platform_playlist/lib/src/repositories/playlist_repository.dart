import "../models/playlist.dart";

abstract class PlaylistRepository {
  Future<List<Playlist>> getAllPlaylists();
  Future<Playlist?> getPlaylistById(String id);
  Future<void> savePlaylist(Playlist playlist);
  Future<void> deletePlaylist(String id);
}
