import "../models/playlist.dart";

abstract class PlaylistExporter {
  Future<String> exportToString(Playlist playlist);
  Future<void> exportToFile(Playlist playlist, String filePath);
}
