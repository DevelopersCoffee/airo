import 'job.dart';
import 'job_cancellation_token.dart';

abstract interface class JobWorker<T extends Job> {
  Type get jobType;
  
  /// Executes the job cooperatively handling cancellation
  Future<void> execute(T job, JobCancellationToken token);
}
