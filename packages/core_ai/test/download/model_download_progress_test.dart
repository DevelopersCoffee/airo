import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelDownloadProgress', () {
    test('treats pending and verifying stages as active progress states', () {
      const pending = ModelDownloadProgress(
        modelId: 'model-a',
        totalBytes: 100,
        downloadedBytes: 0,
        status: ModelDownloadStatus.pending,
      );
      const verifying = ModelDownloadProgress(
        modelId: 'model-a',
        totalBytes: 100,
        downloadedBytes: 100,
        status: ModelDownloadStatus.verifying,
      );

      expect(pending.isActive, isTrue);
      expect(verifying.isActive, isTrue);
      expect(pending.statusDisplay, 'Queued');
      expect(verifying.statusDisplay, 'Verifying');
    });

    test('surfaces queued artifact position when available', () {
      const progress = ModelDownloadProgress(
        modelId: 'model-a',
        totalBytes: 100,
        downloadedBytes: 0,
        status: ModelDownloadStatus.pending,
        queuePosition: 2,
      );

      expect(progress.statusDisplay, 'Queued #3');
      expect(progress.isActive, isTrue);
    });

    test('flags zero-throughput downloads as stalled after threshold', () {
      final lastProgress = DateTime.utc(2026, 8, 1, 10);
      final progress = ModelDownloadProgress(
        modelId: 'model-a',
        totalBytes: 1000,
        downloadedBytes: 400,
        status: ModelDownloadStatus.downloading,
        speedBytesPerSecond: 0,
        lastProgressAt: lastProgress,
      );

      expect(
        progress.isStalledAt(
          DateTime.utc(2026, 8, 1, 10, 1),
          threshold: const Duration(seconds: 90),
        ),
        isFalse,
      );
      expect(
        progress.isStalledAt(
          DateTime.utc(2026, 8, 1, 10, 2),
          threshold: const Duration(seconds: 90),
        ),
        isTrue,
      );
      expect(progress.canPause, isFalse);
      expect(progress.canRetry, isTrue);
      expect(progress.speedDisplay, 'No throughput');
    });
  });
}
