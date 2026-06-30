abstract interface class DownloadRecovery {
  Future<void> saveResumeData(String downloadId, int bytesDownloaded);
  Future<int?> getResumeData(String downloadId);
  Future<void> clearResumeData(String downloadId);
}
