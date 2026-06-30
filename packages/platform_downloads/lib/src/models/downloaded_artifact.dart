class DownloadedArtifact {
  
  const DownloadedArtifact({
    required this.identifier,
    required this.version,
    required this.filePath,
    required this.sizeInBytes,
    required this.sha256Checksum,
  });
  final String identifier;
  final String version;
  final String filePath; // Path in the platform_filesystem
  final int sizeInBytes;
  final String sha256Checksum;
}
