import 'dart:io';

import 'package:airo_background_downloads/airo_background_downloads.dart';
import 'package:flutter_test/flutter_test.dart';

class MockBackgroundDownloads implements BackgroundDownloads {
  int? availableBytesToReturn = 100 * 1024 * 1024; // 100MB
  bool retryCalled = false;
  String? lastRetriedArtifactId;

  @override
  Stream<DownloadProgress> get events => const Stream.empty();

  @override
  Future<void> enqueue(DownloadArtifactRequest request) async {}

  @override
  Future<void> pause(String artifactId) async {}

  @override
  Future<void> resume(String artifactId) async {}

  @override
  Future<void> retry(String artifactId) async {
    retryCalled = true;
    lastRetriedArtifactId = artifactId;
  }

  @override
  Future<void> cancel(String artifactId) async {}

  @override
  Future<DownloadQueueSnapshot> getQueue() async {
    return const DownloadQueueSnapshot(entries: []);
  }

  @override
  Future<int?> getAvailableBytes() async => availableBytesToReturn;
}

void main() {
  group('1. Advanced UX & UI Enhancements', () {
    test(
      'AiroDownloadNotificationController maps progress to active notifications',
      () {
        final controller = AiroDownloadNotificationController(
          config: const DownloadNotificationConfig(
            titlePattern: 'Downloading {name}',
          ),
        );

        const progress = DownloadProgress(
          artifactId: 'video_chunk_1',
          status: DownloadStatus.downloading,
          downloadedBytes: 500,
          totalBytes: 1000,
        );

        controller.handleProgress(progress);
        expect(
          controller.activeNotifications.containsKey('video_chunk_1'),
          isTrue,
        );
        expect(
          controller.formatTitle(progress),
          equals('Downloading video_chunk_1'),
        );

        const completed = DownloadProgress(
          artifactId: 'video_chunk_1',
          status: DownloadStatus.completed,
          downloadedBytes: 1000,
          totalBytes: 1000,
        );

        controller.handleProgress(completed);
        expect(
          controller.activeNotifications.containsKey('video_chunk_1'),
          isFalse,
        );
      },
    );

    test(
      'AiroDownloadQueueVisualizer groups entries and computes overall speed & progress',
      () {
        final entries = [
          const DownloadProgress(
            artifactId: 'item1',
            status: DownloadStatus.downloading,
            downloadedBytes: 50,
            totalBytes: 100,
            speedBytesPerSecond: 1000,
          ),
          const DownloadProgress(
            artifactId: 'item2',
            status: DownloadStatus.queued,
            downloadedBytes: 0,
            totalBytes: 100,
          ),
          const DownloadProgress(
            artifactId: 'item3',
            status: DownloadStatus.paused,
            downloadedBytes: 20,
            totalBytes: 100,
          ),
          const DownloadProgress(
            artifactId: 'item4',
            status: DownloadStatus.completed,
            downloadedBytes: 100,
            totalBytes: 100,
          ),
        ];

        final visualizer = AiroDownloadQueueVisualizer(entries);

        expect(visualizer.downloading.length, equals(1));
        expect(visualizer.queued.length, equals(1));
        expect(visualizer.paused.length, equals(1));
        expect(visualizer.completed.length, equals(1));
        expect(visualizer.totalSpeedBytesPerSecond, equals(1000.0));
        expect(visualizer.overallProgressFraction, equals(0.425));
      },
    );
  });

  group('2. Network & Storage Optimization', () {
    test('AiroNetworkConstraintManager enforces Wi-Fi only constraints', () {
      const manager = AiroNetworkConstraintManager(
        requiredConstraint: NetworkConstraint.wifiOnly,
      );

      expect(
        manager.shouldAllowDownload(isConnected: true, isWifi: true),
        isTrue,
      );
      expect(
        manager.shouldAllowDownload(isConnected: true, isWifi: false),
        isFalse,
      );
      expect(
        manager.shouldAllowDownload(isConnected: false, isWifi: true),
        isFalse,
      );
    });

    test(
      'AiroStorageConstraintManager verifies disk space threshold',
      () async {
        final mock = MockBackgroundDownloads();
        const manager = AiroStorageConstraintManager(
          safetyBufferBytes: 10 * 1024 * 1024,
        );

        // Available: 100MB, Required: 50MB + 10MB safety = 60MB -> Allowed
        expect(
          await manager.hasSufficientStorage(
            downloader: mock,
            expectedBytes: 50 * 1024 * 1024,
          ),
          isTrue,
        );

        // Available: 100MB, Required: 95MB + 10MB safety = 105MB -> Denied
        expect(
          await manager.hasSufficientStorage(
            downloader: mock,
            expectedBytes: 95 * 1024 * 1024,
          ),
          isFalse,
        );
      },
    );

    test(
      'AiroAutoRetryScheduler schedules retry on transport failure',
      () async {
        final mock = MockBackgroundDownloads();
        final scheduler = AiroAutoRetryScheduler(
          downloader: mock,
          maxRetryCount: 2,
          retryDelays: [const Duration(milliseconds: 10)],
        );

        const failedProgress = DownloadProgress(
          artifactId: 'retry_asset',
          status: DownloadStatus.failed,
          downloadedBytes: 10,
          totalBytes: 100,
          failure: DownloadFailure(code: DownloadFailureCode.transport),
        );

        final scheduled = await scheduler.scheduleRetryIfEligible(
          failedProgress,
        );
        expect(scheduled, isTrue);

        await Future.delayed(const Duration(milliseconds: 30));
        expect(mock.retryCalled, isTrue);
        expect(mock.lastRetriedArtifactId, equals('retry_asset'));
      },
    );
  });

  group('3. File Security & Post-Processing', () {
    test(
      'AiroDownloadFileEncryptor encrypts and decrypts file data via stream XOR cipher',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('airo_test_enc');
        final sourceFile = File('${tempDir.path}/test.bin');
        await sourceFile.writeAsBytes([0x01, 0x02, 0x03, 0x04, 0x05]);

        const key = [0xAA, 0xBB];
        const encryptor = AiroDownloadFileEncryptor(secretKey: key);

        final encryptedFile = await encryptor.encryptFile(
          sourcePath: sourceFile.path,
        );
        expect(await encryptedFile.exists(), isTrue);

        final encryptedBytes = await encryptedFile.readAsBytes();
        expect(encryptedBytes[0], equals(0x01 ^ 0xAA));

        // Decrypting using same key restores original data
        final decryptedFile = await encryptor.encryptFile(
          sourcePath: encryptedFile.path,
          destinationPath: '${tempDir.path}/decrypted.bin',
        );
        final decryptedBytes = await decryptedFile.readAsBytes();
        expect(decryptedBytes, equals([0x01, 0x02, 0x03, 0x04, 0x05]));

        await tempDir.delete(recursive: true);
      },
    );
  });

  group('4. Telemetry & Analytics', () {
    test(
      'AiroDownloadTelemetryLogger tracks rates, progress, failures, and snapshots',
      () {
        final logger = AiroDownloadTelemetryLogger();

        logger.recordInitiated(
          DownloadArtifactRequest(
            artifactId: 'telemetry_doc',
            source: Uri.parse('https://example.com/file.pdf'),
            destinationPath: '/tmp/file.pdf',
          ),
        );

        logger.recordProgress(
          const DownloadProgress(
            artifactId: 'telemetry_doc',
            status: DownloadStatus.downloading,
            downloadedBytes: 500,
            totalBytes: 1000,
            speedBytesPerSecond: 2000,
          ),
        );

        logger.recordProgress(
          const DownloadProgress(
            artifactId: 'telemetry_doc',
            status: DownloadStatus.completed,
            downloadedBytes: 1000,
            totalBytes: 1000,
            speedBytesPerSecond: 4000,
          ),
        );

        final snapshot = logger.getSnapshot();
        expect(snapshot.totalInitiated, equals(1));
        expect(snapshot.totalCompleted, equals(1));
        expect(snapshot.totalBytesDownloaded, equals(1000));
        expect(snapshot.averageSpeedBytesPerSecond, equals(3000.0));

        final map = snapshot.toMap();
        expect(map['totalCompleted'], equals(1));
        expect(map['averageSpeedBytesPerSecond'], equals(3000.0));
      },
    );
  });
}
