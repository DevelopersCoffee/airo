// Represents a model entry in the Intelligent Model Manager
class ModelEntry {
  final String id;
  final String name;
  final String version;
  final String description;
  final int sizeBytes;
  final String? localPath;
  final bool isDownloaded;

  ModelEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.sizeBytes,
    this.localPath,
    this.isDownloaded = false,
  });

  // Convert to/from JSON for storage or API communication
  factory ModelEntry.fromJson(Map<String, dynamic> json) => ModelEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as String,
        description: json['description'] as String,
        sizeBytes: json['sizeBytes'] as int,
        localPath: json['localPath'] as String?,
        isDownloaded: json['isDownloaded'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'description': description,
        'sizeBytes': sizeBytes,
        'localPath': localPath,
        'isDownloaded': isDownloaded,
      };
}
