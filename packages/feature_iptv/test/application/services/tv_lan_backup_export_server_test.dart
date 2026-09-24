import 'dart:convert';
import 'dart:io';

import 'package:feature_iptv/application/services/tv_lan_backup_export_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';

void main() {
  const document = AiroBackupDocument(
    fileName: 'backup.json',
    mediaType: 'application/json',
    contents: '{"schema":"airo.tv.backup"}',
  );

  TvLanBackupExportServer serverFor({String token = 'export-token'}) {
    return TvLanBackupExportServer(
      document: document,
      bindAddress: InternetAddress.loopbackIPv4,
      token: token,
      idleTimeout: const Duration(minutes: 5),
    );
  }

  Future<HttpClientResponse> request(Uri url, {String method = 'GET'}) async {
    final client = HttpClient();
    try {
      final httpRequest = await client.openUrl(method, url);
      return await httpRequest.close();
    } finally {
      client.close(force: true);
    }
  }

  test('GET landing page serves download link', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url);
    final content = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(content, contains('Download backup'));
    expect(content, contains('/backup/export/export-token/file'));
  });

  test('GET download serves JSON payload', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final landing = await server.start();
    final download = landing.replace(path: '${landing.path}/file');

    final response = await request(download);
    final content = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(content, document.contents);
  });

  test('unknown token is rejected with 404', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url.replace(path: '/backup/export/wrong'));

    expect(response.statusCode, HttpStatus.notFound);
  });
}
