import os

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

base = 'packages/platform_jobs/lib/src'

# Contracts & Enums
create_file(f'{base}/priorities/job_priority.dart', '''enum JobPriority {
  critical,
  high,
  normal,
  low,
  background
}
''')

create_file(f'{base}/queues/job_queue_type.dart', '''enum JobQueueType {
  runtime,
  downloads,
  knowledge,
  meetings,
  memory,
  workflow,
  maintenance
}
''')

create_file(f'{base}/lifecycle/job_status.dart', '''enum JobStatus {
  created,
  queued,
  scheduled,
  running,
  retrying,
  succeeded,
  failed,
  cancelled
}
''')

create_file(f'{base}/retry/retry_policy.dart', '''enum RetryStrategy {
  noRetry,
  immediate,
  linearBackoff,
  exponentialBackoff
}

class RetryPolicy {
  final RetryStrategy strategy;
  final int maxRetries;
  final Duration initialDelay;

  const RetryPolicy({
    required this.strategy,
    this.maxRetries = 0,
    this.initialDelay = Duration.zero,
  });

  const RetryPolicy.noRetry()
      : strategy = RetryStrategy.noRetry,
        maxRetries = 0,
        initialDelay = Duration.zero;
}
''')

create_file(f'{base}/contracts/job_cancellation_token.dart', '''abstract interface class JobCancellationToken {
  bool get isCancelled;
  Future<void> get onCancelled;
  void throwIfCancelled();
}

abstract interface class JobCancellationTokenSource {
  JobCancellationToken get token;
  void cancel();
}
''')

create_file(f'{base}/contracts/job.dart', '''import '../priorities/job_priority.dart';
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
''')

create_file(f'{base}/contracts/job_worker.dart', '''import 'job.dart';
import 'job_cancellation_token.dart';

abstract interface class JobWorker<T extends Job> {
  Type get jobType;
  
  /// Executes the job cooperatively handling cancellation
  Future<void> execute(T job, JobCancellationToken token);
}
''')

create_file(f'{base}/contracts/job_monitor.dart', '''import 'job.dart';
import '../lifecycle/job_status.dart';

abstract interface class JobMonitor {
  int get activeJobCount;
  int getQueueDepth(JobQueueType queue);
  Duration get averageExecutionTime;
  int get retryCount;
  int get failureCount;
  int get cancellationCount;
  
  JobStatus? getStatus(String jobId);
}
''')

create_file(f'{base}/contracts/job_scheduler.dart', '''import 'job.dart';
import 'job_worker.dart';
import 'job_monitor.dart';

abstract interface class JobScheduler {
  JobMonitor get monitor;
  
  void registerWorker(JobWorker worker);
  
  Future<void> submit(Job job);
  
  Future<void> cancel(String jobId);
}
''')

# Events
create_file(f'{base}/events/job_events.dart', '''import 'package:platform_events/platform_events.dart';
import 'package:platform_core/platform_core.dart' hide PlatformEvent;

abstract class _BaseJobEvent implements PlatformEvent {
  @override
  final String eventId;
  @override
  final DateTime timestamp;
  @override
  final EventCategory category = EventCategory.lifecycle;
  @override
  final SemanticVersion version = const SemanticVersion(major: 1, minor: 0, patch: 0);
  @override
  final String? correlationId;
  @override
  final String? sessionId = null;
  @override
  final String? workspaceId = null;
  @override
  final String? source = 'platform_jobs';
  @override
  final EventMetadata? metadata = null;

  final String jobId;
  final String jobName;

  _BaseJobEvent({
    required this.eventId,
    required this.jobId,
    required this.jobName,
    this.correlationId,
  }) : timestamp = DateTime.now();
}

class JobQueuedEvent extends _BaseJobEvent {
  JobQueuedEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobStartedEvent extends _BaseJobEvent {
  JobStartedEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobProgressEvent extends _BaseJobEvent {
  final double progress; // 0.0 to 1.0
  JobProgressEvent({required super.eventId, required super.jobId, required super.jobName, required this.progress, super.correlationId});
}

class JobSucceededEvent extends _BaseJobEvent {
  JobSucceededEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobFailedEvent extends _BaseJobEvent {
  final String error;
  JobFailedEvent({required super.eventId, required super.jobId, required super.jobName, required this.error, super.correlationId});
}

class JobCancelledEvent extends _BaseJobEvent {
  JobCancelledEvent({required super.eventId, required super.jobId, required super.jobName, super.correlationId});
}

class JobRetriedEvent extends _BaseJobEvent {
  final int attempt;
  JobRetriedEvent({required super.eventId, required super.jobId, required super.jobName, required this.attempt, super.correlationId});
}
''')

# Implementations
create_file(f'{base}/cancellation/default_cancellation_token.dart', '''import 'dart:async';
import '../contracts/job_cancellation_token.dart';

class DefaultCancellationTokenSource implements JobCancellationTokenSource {
  final Completer<void> _completer = Completer<void>();
  late final DefaultCancellationToken _token;

  DefaultCancellationTokenSource() {
    _token = DefaultCancellationToken(this);
  }

  @override
  JobCancellationToken get token => _token;

  @override
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  bool get isCancelled => _completer.isCompleted;
  Future<void> get onCancelled => _completer.future;
}

class DefaultCancellationToken implements JobCancellationToken {
  final DefaultCancellationTokenSource _source;

  DefaultCancellationToken(this._source);

  @override
  bool get isCancelled => _source.isCancelled;

  @override
  Future<void> get onCancelled => _source.onCancelled;

  @override
  void throwIfCancelled() {
    if (isCancelled) {
      throw StateError('Job was cancelled');
    }
  }
}
''')

create_file(f'{base}/scheduler/default_job_scheduler.dart', '''import 'dart:async';
import 'package:uuid/uuid.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_logging/platform_logging.dart';
import '../contracts/job_scheduler.dart';
import '../contracts/job_worker.dart';
import '../contracts/job_monitor.dart';
import '../contracts/job.dart';
import '../contracts/job_cancellation_token.dart';
import '../lifecycle/job_status.dart';
import '../queues/job_queue_type.dart';
import '../events/job_events.dart';
import '../cancellation/default_cancellation_token.dart';
import '../retry/retry_policy.dart';

class _JobRecord {
  final Job job;
  final DefaultCancellationTokenSource cancellationSource;
  JobStatus status;
  int retryCount;
  final DateTime queuedAt;
  DateTime? startedAt;

  _JobRecord(this.job)
      : cancellationSource = DefaultCancellationTokenSource(),
        status = JobStatus.created,
        retryCount = 0,
        queuedAt = DateTime.now();
}

class DefaultJobScheduler implements JobScheduler, JobMonitor {
  final EventPublisher _eventPublisher;
  final Logger _logger;
  final _uuid = const Uuid();

  final Map<Type, JobWorker> _workers = {};
  final Map<String, _JobRecord> _jobs = {};

  // Monitoring stats
  int _totalCompleted = 0;
  int _totalFailures = 0;
  int _totalCancellations = 0;
  int _totalRetries = 0;
  Duration _totalExecutionTime = Duration.zero;

  DefaultJobScheduler(this._eventPublisher, this._logger);

  @override
  JobMonitor get monitor => this;

  @override
  void registerWorker(JobWorker worker) {
    _workers[worker.jobType] = worker;
    _logger.info('Registered worker for \${worker.jobType}');
  }

  @override
  Future<void> submit(Job job) async {
    final record = _JobRecord(job);
    _jobs[job.id] = record;
    
    _transition(record, JobStatus.queued);
    
    // In-memory simplistic execution (no actual queue loops for now, immediate dispatch async)
    unawaited(_executeJob(record));
  }

  @override
  Future<void> cancel(String jobId) async {
    final record = _jobs[jobId];
    if (record != null && record.status == JobStatus.running) {
      record.cancellationSource.cancel();
    }
  }

  Future<void> _executeJob(_JobRecord record) async {
    final worker = _workers[record.job.runtimeType];
    if (worker == null) {
      _logger.error('No worker registered for \${record.job.runtimeType}');
      _transition(record, JobStatus.failed, error: 'No worker registered');
      return;
    }

    _transition(record, JobStatus.running);

    while (true) {
      try {
        await worker.execute(record.job, record.cancellationSource.token);
        _transition(record, JobStatus.succeeded);
        break;
      } catch (e) {
        if (record.cancellationSource.isCancelled || e is StateError && e.message == 'Job was cancelled') {
          _transition(record, JobStatus.cancelled);
          break;
        }

        if (record.retryCount < record.job.retryPolicy.maxRetries) {
          record.retryCount++;
          _totalRetries++;
          _transition(record, JobStatus.retrying);
          
          await _delayForRetry(record.job.retryPolicy, record.retryCount);
          _transition(record, JobStatus.running);
        } else {
          _transition(record, JobStatus.failed, error: e.toString());
          break;
        }
      }
    }
  }
  
  Future<void> _delayForRetry(RetryPolicy policy, int attempt) async {
    if (policy.strategy == RetryStrategy.immediate) return;
    
    Duration delay = policy.initialDelay;
    if (policy.strategy == RetryStrategy.exponentialBackoff) {
      delay = delay * (1 << (attempt - 1));
    } else if (policy.strategy == RetryStrategy.linearBackoff) {
      delay = delay * attempt;
    }
    await Future.delayed(delay);
  }

  void _transition(_JobRecord record, JobStatus newStatus, {String? error}) {
    record.status = newStatus;
    final jobId = record.job.id;
    final jobName = record.job.name;
    final eventId = _uuid.v4();

    switch (newStatus) {
      case JobStatus.queued:
        _eventPublisher.publish(JobQueuedEvent(eventId: eventId, jobId: jobId, jobName: jobName));
        break;
      case JobStatus.running:
        if (record.startedAt == null) record.startedAt = DateTime.now();
        _eventPublisher.publish(JobStartedEvent(eventId: eventId, jobId: jobId, jobName: jobName));
        break;
      case JobStatus.succeeded:
        _totalCompleted++;
        _totalExecutionTime += DateTime.now().difference(record.startedAt!);
        _jobs.remove(jobId);
        _eventPublisher.publish(JobSucceededEvent(eventId: eventId, jobId: jobId, jobName: jobName));
        break;
      case JobStatus.failed:
        _totalFailures++;
        if (record.startedAt != null) _totalExecutionTime += DateTime.now().difference(record.startedAt!);
        _jobs.remove(jobId);
        _eventPublisher.publish(JobFailedEvent(eventId: eventId, jobId: jobId, jobName: jobName, error: error ?? 'Unknown error'));
        break;
      case JobStatus.cancelled:
        _totalCancellations++;
        if (record.startedAt != null) _totalExecutionTime += DateTime.now().difference(record.startedAt!);
        _jobs.remove(jobId);
        _eventPublisher.publish(JobCancelledEvent(eventId: eventId, jobId: jobId, jobName: jobName));
        break;
      case JobStatus.retrying:
        _eventPublisher.publish(JobRetriedEvent(eventId: eventId, jobId: jobId, jobName: jobName, attempt: record.retryCount));
        break;
      default:
        break;
    }
  }

  // Monitor implementation
  @override
  int get activeJobCount => _jobs.values.where((j) => j.status == JobStatus.running).length;

  @override
  int getQueueDepth(JobQueueType queue) => _jobs.values.where((j) => j.job.queue == queue && (j.status == JobStatus.queued || j.status == JobStatus.retrying)).length;

  @override
  Duration get averageExecutionTime => _totalCompleted == 0 ? Duration.zero : Duration(microseconds: _totalExecutionTime.inMicroseconds ~/ _totalCompleted);

  @override
  int get retryCount => _totalRetries;

  @override
  int get failureCount => _totalFailures;

  @override
  int get cancellationCount => _totalCancellations;

  @override
  JobStatus? getStatus(String jobId) => _jobs[jobId]?.status;
}
''')

# Bootstrap
create_file(f'{base}/bootstrap/jobs_bootstrap_task.dart', '''import 'package:platform_core/platform_core.dart';
import '../contracts/job_scheduler.dart';

class JobsBootstrapTask implements BootstrapTask {
  final JobScheduler _scheduler;

  JobsBootstrapTask(this._scheduler);

  @override
  String get name => 'PlatformJobs';

  @override
  BootstrapPhase get phase => BootstrapPhase.jobs;

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    try {
      // Logic for recovering persisted jobs would go here
      return const BootstrapResult.success(BootstrapPhase.jobs);
    } catch (e) {
      return BootstrapResult.failure(BootstrapPhase.jobs, e.toString());
    }
  }
}
''')

# Providers
create_file(f'{base}/providers/jobs_providers.dart', '''import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_logging/platform_logging.dart';
import '../contracts/job_scheduler.dart';
import '../contracts/job_monitor.dart';
import '../scheduler/default_job_scheduler.dart';

final jobSchedulerProvider = Provider<JobScheduler>((ref) {
  final eventPublisher = ref.watch(eventPublisherProvider);
  final logger = ref.watch(loggerProvider);
  return DefaultJobScheduler(eventPublisher, logger);
});

final jobMonitorProvider = Provider<JobMonitor>((ref) {
  return ref.watch(jobSchedulerProvider).monitor;
});
''')

# Export file
create_file('packages/platform_jobs/lib/platform_jobs.dart', '''library platform_jobs;

export 'src/contracts/job.dart';
export 'src/contracts/job_scheduler.dart';
export 'src/contracts/job_executor.dart';
export 'src/contracts/job_worker.dart';
export 'src/contracts/job_queue.dart';
export 'src/contracts/job_monitor.dart';
export 'src/contracts/job_cancellation_token.dart';

export 'src/priorities/job_priority.dart';
export 'src/queues/job_queue_type.dart';
export 'src/lifecycle/job_status.dart';
export 'src/retry/retry_policy.dart';

export 'src/events/job_events.dart';
export 'src/providers/jobs_providers.dart';
export 'src/bootstrap/jobs_bootstrap_task.dart';
''')

print("Created all platform_jobs files.")
