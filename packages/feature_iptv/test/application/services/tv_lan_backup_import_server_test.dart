import 'dart:convert';
import 'dart:io';

import 'package:feature_iptv/application/services/tv_lan_backup_import_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TvLanBackupImportServer serverFor({String token = 'import-token'}) {
    return TvLanBackupImportServer(
      bindAddress: InternetAddress.loopbackIPv4,
      token: token,
      idleTimeout: const Duration(minutes: 5),
      stopGracePeriod: const Duration(milliseconds: 20),
    );
  }

  Future<HttpClientResponse> request(
    Uri url, {
    String method = 'GET',
    String? body,
  }) async {
    final client = HttpClient();
    try {
      final httpRequest = await client.openUrl(method, url);
      if (body != null) {
        httpRequest.headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        );
        httpRequest.write(body);
      }
      return await httpRequest.close();
    } finally {
      client.close(force: true);
    }
  }

  test('GET serves upload form', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(url);
    final content = await response.transform(utf8.decoder).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(content, contains('<input'));
  });

  test('POST with JSON completes result and consumes token', () async {
    final server = serverFor();
    addTearDown(server.stop);
    final url = await server.start();

    final response = await request(
      url,
      method: 'POST',
      body: '{"schema":"airo.tv.backup","version":1}',
    );

    expect(response.statusCode, HttpStatus.ok);
    final document = await server.result;
    expect(document?.contents, contains('airo.tv.backup'));

    final retry = await request(
      url,
      method: 'POST',
      body: '{"schema":"airo.tv.backup","version":1}',
    );
    expect(retry.statusCode, HttpStatus.gone);
  });
}
