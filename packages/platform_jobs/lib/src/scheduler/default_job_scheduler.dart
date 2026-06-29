import 'dart:async';
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
    _logger.info('Registered worker for ${worker.jobType}');
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
      _logger.error('No worker registered for ${record.job.runtimeType}');
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
