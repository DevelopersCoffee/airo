import 'dart:convert';
import 'dart:io';

import 'package:airo_background_downloads/airo_background_downloads.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AiroChecksumProcessor rejects wrong SHA-256 hash', () async {
    final tempDir = await Directory.systemTemp.createTemp('checksum-proc-');
    addTearDown(() => tempDir.delete(recursive: true));

    final file = File('${tempDir.path}/payload.bin');
    await file.writeAsBytes(utf8.encode('checksum-test-payload'));

    final actual = sha256
        .convert(utf8.encode('checksum-test-payload'))
        .toString();
    final wrong = actual.replaceFirst('a', 'b');

    const processor = AiroChecksumProcessor();
    final download = AiroDownload(
      request: AiroDownloadRequest(
        id: 'checksum-test',
        url: Uri.parse('https://example.com/payload.bin'),
        destination: file.path,
        checksum: AiroChecksum(
          algorithm: AiroChecksumAlgorithm.sha256,
          value: wrong,
        ),
      ),
      status: AiroDownloadStatus.completed,
      downloadedBytes: 0,
      totalBytes: 0,
    );

    final result = await processor.process(
      AiroProcessorContext(download: download, filePath: file.path),
    );
    expect(result.success, isFalse);
    expect(result.errorMessage, contains('sha256'));
  });

  test(
    'AiroChecksumProcessor accepts matching SHA-256 (case-insensitive)',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('checksum-proc-');
      addTearDown(() => tempDir.delete(recursive: true));

      final bytes = utf8.encode('checksum-ok');
      final file = File('${tempDir.path}/payload.bin');
      await file.writeAsBytes(bytes);

      final hex = sha256.convert(bytes).toString().toUpperCase();

      const processor = AiroChecksumProcessor();
      final download = AiroDownload(
        request: AiroDownloadRequest(
          id: 'checksum-ok',
          url: Uri.parse('https://example.com/payload.bin'),
          destination: file.path,
          checksum: AiroChecksum(
            algorithm: AiroChecksumAlgorithm.sha256,
            value: hex,
          ),
        ),
        status: AiroDownloadStatus.completed,
        downloadedBytes: 0,
        totalBytes: 0,
      );

      final result = await processor.process(
        AiroProcessorContext(download: download, filePath: file.path),
      );
      expect(result.success, isTrue);
    },
  );
}
