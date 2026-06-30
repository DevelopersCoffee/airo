class DownloadArtifactDescriptor {
  
  const DownloadArtifactDescriptor({
    required this.name,
    required this.primaryUrl,
    required this.sizeInBytes, required this.sha256Checksum, this.mirrors = const [],
    this.compression,
    this.signature,
  });
  final String name;
  final String primaryUrl;
  final List<String> mirrors;
  final int sizeInBytes;
  final String sha256Checksum;
  final String? compression;
  final String? signature;
}

class DownloadManifest {

  const DownloadManifest({
    required this.identifier,
    required this.version,
    this.artifacts = const [],
    this.dependencies = const [],
  });
  final String identifier;
  final String version;
  final List<DownloadArtifactDescriptor> artifacts;
  final List<String> dependencies;

  int get totalSizeInBytes => artifacts.fold<int>(0, (sum, a) => sum + a.sizeInBytes);
}
