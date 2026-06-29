import '../priorities/job_priority.dart';
import '../retry/retry_policy.dart';
import '../queues/job_queue_type.dart';

abstract interface class Job<T> {
  String get id;
  String get name;
  JobQueueType get queue;
  JobPriority get priority;
  RetryPolicy get retryPolicy;
  
  T get payload;
}
