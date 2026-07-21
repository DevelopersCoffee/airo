/// Public contract types for playlist export flows.
library;

/// Supported output formats for playlist export.
enum PlaylistExportFormat {
  m3u(
    fileExtension: 'm3u',
    mediaType: 'audio/x-mpegurl',
  ),
  json(
    fileExtension: 'json',
    mediaType: 'application/json',
  );

  const PlaylistExportFormat({
    required this.fileExtension,
    required this.mediaType,
  });

  final String fileExtension;
  final String mediaType;
}

/// Immutable request metadata for an export operation.
class PlaylistExportRequest {
  const PlaylistExportRequest({
    required this.format,
    required this.playlistId,
    required this.playlistTitle,
    this.includeGroups = true,
    this.includeEpgMetadata = false,
  });

  final PlaylistExportFormat format;
  final String playlistId;
  final String playlistTitle;
  final bool includeGroups;
  final bool includeEpgMetadata;

  /// Returns a filesystem-safe suggestion for the exported filename.
  String suggestedFileName() {
    final normalizedTitle = playlistTitle
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final stem = normalizedTitle.isEmpty ? 'playlist_export' : normalizedTitle;
    return '$stem.${format.fileExtension}';
  }

  Map<String, Object> toMap() {
    return <String, Object>{
      'format': format.name,
      'playlistId': playlistId,
      'playlistTitle': playlistTitle,
      'includeGroups': includeGroups,
      'includeEpgMetadata': includeEpgMetadata,
      'suggestedFileName': suggestedFileName(),
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaylistExportRequest &&
            runtimeType == other.runtimeType &&
            format == other.format &&
            playlistId == other.playlistId &&
            playlistTitle == other.playlistTitle &&
            includeGroups == other.includeGroups &&
            includeEpgMetadata == other.includeEpgMetadata;
  }

  @override
  int get hashCode => Object.hash(
    format,
    playlistId,
    playlistTitle,
    includeGroups,
    includeEpgMetadata,
  );
}

/// Immutable export output container for downstream storage or share flows.
class PlaylistExportResult {
  const PlaylistExportResult({
    required this.request,
    required this.contents,
  });

  final PlaylistExportRequest request;
  final String contents;

  String get mediaType => request.format.mediaType;

  String get suggestedFileName => request.suggestedFileName();

  Map<String, Object> toMap() {
    return <String, Object>{
      'request': request.toMap(),
      'mediaType': mediaType,
      'suggestedFileName': suggestedFileName,
      'contents': contents,
    };
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PlaylistExportResult &&
            runtimeType == other.runtimeType &&
            request == other.request &&
            contents == other.contents;
  }

  @override
  int get hashCode => Object.hash(request, contents);
}
