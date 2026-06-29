import 'job.dart';
import '../lifecycle/job_status.dart';
import '../queues/job_queue_type.dart';

abstract interface class JobMonitor {
  int get activeJobCount;
  int getQueueDepth(JobQueueType queue);
  Duration get averageExecutionTime;
  int get retryCount;
  int get failureCount;
  int get cancellationCount;
  
  JobStatus? getStatus(String jobId);
}
