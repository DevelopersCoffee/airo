import 'job.dart';
import 'job_cancellation_token.dart';

abstract interface class JobExecutor {
  Future<void> executeJob(Job job, JobCancellationToken token);
}
