import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  group('PlaylistExportRequest', () {
    test('builds a sanitized filename from playlist title and format', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.m3u,
        playlistId: 'sports-01',
        playlistTitle: 'Sports & News / 24x7',
      );

      expect(request.suggestedFileName(), 'Sports_News_24x7.m3u');
    });

    test('falls back to a stable filename when title normalizes to empty', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'empty-01',
        playlistTitle: '***',
      );

      expect(request.suggestedFileName(), 'playlist_export.json');
    });

    test('serializes request metadata for downstream exporters', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'kids',
        playlistTitle: 'Kids',
        includeGroups: false,
        includeEpgMetadata: true,
      );

      expect(request.toMap(), <String, Object>{
        'format': 'json',
        'playlistId': 'kids',
        'playlistTitle': 'Kids',
        'includeGroups': false,
        'includeEpgMetadata': true,
        'suggestedFileName': 'Kids.json',
      });
    });
  });

  group('PlaylistExportResult', () {
    test('exposes derived media type and file name from request', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.m3u,
        playlistId: 'news',
        playlistTitle: 'Daily News',
      );
      const result = PlaylistExportResult(
        request: request,
        contents: '#EXTM3U',
      );

      expect(result.mediaType, 'audio/x-mpegurl');
      expect(result.suggestedFileName, 'Daily_News.m3u');
    });

    test('serializes the export result envelope', () {
      const request = PlaylistExportRequest(
        format: PlaylistExportFormat.json,
        playlistId: 'all',
        playlistTitle: 'All Channels',
      );
      const result = PlaylistExportResult(
        request: request,
        contents: '{"channels":[]}',
      );

      expect(result.toMap(), <String, Object>{
        'request': <String, Object>{
          'format': 'json',
          'playlistId': 'all',
          'playlistTitle': 'All Channels',
          'includeGroups': true,
          'includeEpgMetadata': false,
          'suggestedFileName': 'All_Channels.json',
        },
        'mediaType': 'application/json',
        'suggestedFileName': 'All_Channels.json',
        'contents': '{"channels":[]}',
      });
    });
  });
}
