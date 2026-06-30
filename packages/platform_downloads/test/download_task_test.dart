import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_downloads/platform_downloads.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_jobs/platform_jobs.dart';

class MockTransport extends Mock implements DownloadTransport {}
class MockVerifier extends Mock implements DownloadVerifier {}
class MockEventBus extends Mock implements EventBus {}
class MockToken extends Mock implements JobCancellationToken {}

void main() {
  test('DownloadJob initializes correctly', () {
    const manifest = DownloadManifest(
      identifier: 'test-model',
      version: '1.0.0',
    );
    
    final job = DownloadJob(
      id: 'job-1',
      payload: manifest,
    );

    expect(job.id, 'job-1');
    expect(job.name, 'Download test-model');
  });

  test('DownloadJobExecutor handles job execution', () async {
    final executor = DownloadJobExecutor(
      transport: MockTransport(),
      verifier: MockVerifier(),
      eventBus: MockEventBus(),
    );

    final job = DownloadJob(
      id: 'job-1',
      payload: const DownloadManifest(
        identifier: 'test-model',
        version: '1.0.0',
      ),
    );

    final token = MockToken();
    when(() => token.isCancelled).thenReturn(false);

    await executor.executeJob(job, token);
    
    verify(() => token.isCancelled).called(greaterThan(0));
  });
}
