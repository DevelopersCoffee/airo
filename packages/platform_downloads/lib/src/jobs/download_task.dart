import 'package:platform_downloads/src/manifest/download_manifest.dart';
import 'package:platform_downloads/src/transport/download_transport.dart';
import 'package:platform_downloads/src/verification/download_verifier.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_jobs/platform_jobs.dart';

class DownloadJob implements Job<DownloadManifest> {

  DownloadJob({
    required this.id,
    required this.payload,
  }) : name = 'Download ${payload.identifier}';
  @override
  final String id;
  @override
  final String name;
  @override
  final DownloadManifest payload;
  @override
  final JobPriority priority = JobPriority.normal;
  @override
  final JobQueueType queue = JobQueueType.downloads;
  @override
  final RetryPolicy retryPolicy = const RetryPolicy(strategy: RetryStrategy.exponentialBackoff, maxRetries: 3);
}

class DownloadJobExecutor implements JobExecutor {

  DownloadJobExecutor({
    required this.transport,
    required this.verifier,
    required this.eventBus,
  });
  final DownloadTransport transport;
  final DownloadVerifier verifier;
  final EventBus eventBus;

  @override
  Future<void> executeJob(Job job, JobCancellationToken token) async {
    if (job is! DownloadJob) return;
    // Simulated state machine for architectural purposes
    await Future.delayed(const Duration(milliseconds: 100));
    if (token.isCancelled) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
    if (token.isCancelled) return;
    
    await Future.delayed(const Duration(milliseconds: 100));
  }
}
