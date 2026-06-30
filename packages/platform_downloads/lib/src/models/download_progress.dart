class DownloadProgress {

  const DownloadProgress({
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.throughputBytesPerSecond = 0.0,
    this.estimatedTimeRemaining,
    this.verificationProgress = 0.0,
    this.installProgress = 0.0,
  });
  final int bytesDownloaded;
  final int totalBytes;
  final double throughputBytesPerSecond;
  final Duration? estimatedTimeRemaining;
  final double verificationProgress;
  final double installProgress;
}
