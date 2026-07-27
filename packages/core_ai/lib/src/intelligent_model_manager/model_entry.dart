import 'package:meta/meta.dart';

enum ModelUpdateState { notInstalled, unknown, upToDate, updateAvailable }

/// Product-neutral view state for one catalog model.
@immutable
class ModelEntry {
  const ModelEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.sizeBytes,
    required this.updateState,
    this.installedVersion,
    this.localPath,
    this.isDownloaded = false,
    this.isActive = false,
    this.isRecommended = false,
    this.preloadFrequentlyUsed = false,
    this.isResident = false,
  });

  final String id;
  final String name;
  final String version;
  final String? installedVersion;
  final String description;
  final int sizeBytes;

  /// Retained for source compatibility; manager snapshots always leave this
  /// null so application state cannot expose sandbox paths.
  @Deprecated('Use isDownloaded; local paths are not part of manager state.')
  final String? localPath;
  final bool isDownloaded;
  final bool isActive;
  final bool isRecommended;
  final bool preloadFrequentlyUsed;
  final bool isResident;
  final ModelUpdateState updateState;

  bool get hasUpdate => updateState == ModelUpdateState.updateAvailable;

  factory ModelEntry.fromJson(Map<String, dynamic> json) => ModelEntry(
    id: json['id'] as String,
    name: json['name'] as String,
    version: json['version'] as String,
    installedVersion: json['installedVersion'] as String?,
    description: json['description'] as String,
    sizeBytes: json['sizeBytes'] as int,
    localPath: json['localPath'] as String?,
    isDownloaded: json['isDownloaded'] as bool? ?? false,
    isActive: json['isActive'] as bool? ?? false,
    isRecommended: json['isRecommended'] as bool? ?? false,
    preloadFrequentlyUsed: json['preloadFrequentlyUsed'] as bool? ?? false,
    isResident: json['isResident'] as bool? ?? false,
    updateState: ModelUpdateState.values.byName(
      json['updateState'] as String? ?? ModelUpdateState.notInstalled.name,
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'installedVersion': installedVersion,
    'description': description,
    'sizeBytes': sizeBytes,
    'localPath': localPath,
    'isDownloaded': isDownloaded,
    'isActive': isActive,
    'isRecommended': isRecommended,
    'preloadFrequentlyUsed': preloadFrequentlyUsed,
    'isResident': isResident,
    'updateState': updateState.name,
  };
}
