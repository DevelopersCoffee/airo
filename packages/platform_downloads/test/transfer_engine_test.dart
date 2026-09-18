import 'package:flutter_test/flutter_test.dart';
import 'package:platform_downloads/platform_downloads.dart';

void main() {
  test('re-exports the 1.2.0 transfer engine types', () {
    const policy = AiroDownloadPolicy(
      network: NetworkPolicy.unmetered,
      power: PowerPolicy.charging,
      retryPolicy: RetryPolicy.exponential,
    );
    final request = AiroDownloadRequest(
      id: 'model-a',
      url: Uri.parse('https://example.test/model.bin'),
      destination: '/sandbox/model.bin',
      expectedBytes: 1024,
      checksum: const AiroChecksum(
        algorithm: AiroChecksumAlgorithm.sha256,
        value: 'abc',
      ),
      policy: policy,
    );
    const storage = AiroStorageRequirement(
      downloadBytes: 1024,
      temporaryBytes: 128,
      processingBytes: 64,
      safetyBytes: 256,
    );

    const capabilities = AiroPlatformCapabilities(
      backgroundDownloads: true,
      pauseResume: true,
      networkConstraints: true,
      chargingConstraints: true,
      checksumVerification: true,
      backgroundProcessing: false,
      notifications: true,
    );

    expect(request.id, 'model-a');
    expect(request.policy.network, NetworkPolicy.unmetered);
    expect(AiroDownloadStatus.values, contains(AiroDownloadStatus.queued));
    expect(storage.totalRequiredBytes, 1024 + 128 + 64 + 256);
    expect(capabilities.backgroundDownloads, isTrue);
  });
}
