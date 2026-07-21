# platform_playlist_export

`platform_playlist_export` defines the small typed contract that Airo uses when
turning an in-memory playlist into a downloadable or shareable export artifact.

The package intentionally stays implementation-free. It does not choose where
exports are stored, how files are shared, or how playlist rows are rendered.
Those decisions belong to application code or a higher-level platform adapter.

## What It Provides

- `PlaylistExportFormat` for supported output formats and their MIME metadata.
- `PlaylistExportRequest` for immutable export inputs and filename generation.
- `PlaylistExportResult` for passing serialized export content to storage,
  sharing, or download flows.

## Usage

```dart
import 'package:platform_playlist_export/platform_playlist_export.dart';

const request = PlaylistExportRequest(
  format: PlaylistExportFormat.m3u,
  playlistId: 'favorites',
  playlistTitle: 'Favorites',
);

final result = PlaylistExportResult(
  request: request,
  contents: '#EXTM3U\n#EXTINF:-1,Channel 1\nhttps://example.com/live.m3u8',
);
```

The caller can then persist `result.contents`, attach `result.mediaType`, and
use `result.suggestedFileName` when presenting a save or share action.

## Validation

Run the package-local checks:

```bash
cd packages/platform_playlist_export
flutter analyze
flutter test
```
