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
  });
}
