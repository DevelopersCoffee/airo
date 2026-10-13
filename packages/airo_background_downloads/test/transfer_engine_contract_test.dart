import 'package:airo_background_downloads/airo_background_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Airo Transfer Engine Contract', () {
    test(
      'AiroDownloadPolicy describes execution intent without platform leakage',
      () {
        const policy = AiroDownloadPolicy(
          network: NetworkPolicy.unmetered,
          power: PowerPolicy.charging,
          allowMetered: false,
          maxRetries: 5,
          retryPolicy: RetryPolicy.exponential,
        );

        final map = policy.toMap();
        expect(map['network'], equals('unmetered'));
        expect(map['power'], equals('charging'));
        expect(map['allowMetered'], isFalse);
        expect(map['maxRetries'], equals(5));
        expect(map['retryPolicy'], equals('exponential'));

        final restored = AiroDownloadPolicy.fromMap(map);
        expect(restored.network, equals(NetworkPolicy.unmetered));
        expect(restored.power, equals(PowerPolicy.charging));
      },
    );

    test(
      'AiroDownloadRequest uses application-supplied ID and intent policy',
      () {
        final request = AiroDownloadRequest(
          id: 'movie-1080p-id-1',
          url: Uri.parse('https://example.com/stream/movie.mp4'),
          destination: '/app/storage/movie.mp4',
          expectedBytes: 1000000,
          checksum: const AiroChecksum(
            algorithm: AiroChecksumAlgorithm.sha256,
            value: 'a1b2c3d4e5f6',
          ),
          headers: const {'Authorization': 'Bearer test-token'},
        );

        final map = request.toMap();
        expect(map['id'], equals('movie-1080p-id-1'));
        expect(map['url'], equals('https://example.com/stream/movie.mp4'));
        expect(map['destination'], equals('/app/storage/movie.mp4'));
        expect(map['expectedBytes'], equals(1000000));
        expect(request.headers['Authorization'], equals('Bearer test-token'));

        final restored = AiroDownloadRequest.fromMap(map);
        expect(restored.id, equals('movie-1080p-id-1'));
        expect(
          restored.checksum?.algorithm,
          equals(AiroChecksumAlgorithm.sha256),
        );
      },
    );

    test('AiroDownloadStatus exposes granular states for UI display', () {
      final request = AiroDownloadRequest(
        id: 'epg-pack-india',
        url: Uri.parse('https://example.com/epg.xml'),
        destination: '/app/epg.xml',
      );

      final download = AiroDownload(
        request: request,
        status: AiroDownloadStatus.waitingForNetwork,
        downloadedBytes: 400,
        totalBytes: 1000,
        speedBytesPerSecond: 0,
      );

      expect(download.fraction, equals(0.4));
      expect(download.status, equals(AiroDownloadStatus.waitingForNetwork));
      expect(download.isTerminal, isFalse);
    });

    test(
      'AiroStorageRequirement computes total required bytes with safety buffer',
      () {
        const requirement = AiroStorageRequirement(
          downloadBytes: 100 * 1024 * 1024,
          temporaryBytes: 20 * 1024 * 1024,
          processingBytes: 10 * 1024 * 1024,
          safetyBytes: 50 * 1024 * 1024,
        );

        expect(requirement.totalRequiredBytes, equals(180 * 1024 * 1024));
      },
    );

    test('AiroDownloadEngine runs pluggable processor pipeline', () async {
      final engine = AiroDownloadEngine(
        processors: [const AiroChecksumProcessor()],
      );

      final request = AiroDownloadRequest(
        id: 'test-processor',
        url: Uri.parse('https://example.com/file.bin'),
        destination: '/tmp/file.bin',
      );

      final download = AiroDownload(
        request: request,
        status: AiroDownloadStatus.completed,
        downloadedBytes: 100,
        totalBytes: 100,
      );

      final result = await engine.runProcessors(download, '/tmp/file.bin');
      expect(result.success, isTrue);
      expect(result.outputFilePath, equals('/tmp/file.bin'));
    });
  });
}
