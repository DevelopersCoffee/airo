abstract class PlaylistImporter {
  Future<void> importFromUrl(String url);
  Future<void> importFromFile(String filePath);
}
