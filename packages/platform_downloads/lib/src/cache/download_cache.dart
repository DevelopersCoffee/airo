abstract interface class DownloadCache {
  Future<String?> getCachedFilePath(String sha256Checksum);
  Future<void> registerCachedFile(String sha256Checksum, String filePath);
}
