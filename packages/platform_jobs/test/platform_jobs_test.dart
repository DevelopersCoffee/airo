import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_jobs/platform_jobs.dart';
import 'package:platform_jobs/src/scheduler/default_job_scheduler.dart';
import 'package:platform_events/platform_events.dart';
import 'package:platform_logging/platform_logging.dart';

class MockEventPublisher implements EventPublisher {
  final List<PlatformEvent> events = [];
  @override
  void publish(PlatformEvent event) {
    events.add(event);
  }
}

class MockLogger implements Logger {
  @override
  void info(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void error(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void debug(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void warning(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void fatal(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void trace(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
  @override
  void warn(String message, {LogCategory category = LogCategory.platform, Object? error, StackTrace? stackTrace, LogMetadata? metadata}) {}
}

class TestJob implements Job<String> {
  @override
  final String id = 'job_1';
  @override
  final String name = 'Test Job';
  @override
  final JobPriority priority = JobPriority.normal;
  @override
  final JobQueueType queue = JobQueueType.downloads;
  @override
  final RetryPolicy retryPolicy = const RetryPolicy.noRetry();
  
  @override
  final String payload = 'payload_data';
}

class TestWorker implements JobWorker<TestJob> {
  @override
  Type get jobType => TestJob;
  
  bool executed = false;
  
  @override
  Future<void> execute(TestJob job, JobCancellationToken token) async {
    executed = true;
    expect(job.payload, 'payload_data');
  }
}

class RetryingJob implements Job<String> {
  @override
  final String id = 'job_retry';
  @override
  final String name = 'Retry Job';
  @override
  final JobPriority priority = JobPriority.normal;
  @override
  final JobQueueType queue = JobQueueType.downloads;
  @override
  final RetryPolicy retryPolicy = const RetryPolicy(strategy: RetryStrategy.immediate, maxRetries: 1);
  
  @override
  final String payload = '';
}

class FailingWorker implements JobWorker<RetryingJob> {
  @override
  Type get jobType => RetryingJob;
  
  int attempts = 0;
  
  @override
  Future<void> execute(RetryingJob job, JobCancellationToken token) async {
    attempts++;
    if (attempts == 1) {
      throw Exception('First attempt failed');
    }
  }
}

class CancellableJob implements Job<String> {
  @override
  final String id = 'job_cancel';
  @override
  final String name = 'Cancel Job';
  @override
  final JobPriority priority = JobPriority.normal;
  @override
  final JobQueueType queue = JobQueueType.downloads;
  @override
  final RetryPolicy retryPolicy = const RetryPolicy.noRetry();
  
  @override
  final String payload = '';
}

class LongRunningWorker implements JobWorker<CancellableJob> {
  @override
  Type get jobType => CancellableJob;
  
  bool finished = false;
  
  @override
  Future<void> execute(CancellableJob job, JobCancellationToken token) async {
    while (!token.isCancelled) {
      await Future.delayed(const Duration(milliseconds: 10));
    }
    token.throwIfCancelled();
    finished = true;
  }
}

void main() {
  late DefaultJobScheduler scheduler;
  late MockEventPublisher eventPublisher;

  setUp(() {
    eventPublisher = MockEventPublisher();
    scheduler = DefaultJobScheduler(eventPublisher, MockLogger());
  });

  test('Scheduler executes job and publishes events', () async {
    final worker = TestWorker();
    scheduler.registerWorker(worker);
    
    await scheduler.submit(TestJob());
    
    // Give event loop a tick to process the async dispatch
    await Future.delayed(Duration.zero);
    
    expect(worker.executed, isTrue);
    expect(scheduler.monitor.activeJobCount, 0);
    
    // Check events: Queued -> Started -> Succeeded
    expect(eventPublisher.events.length, 3);
    expect(eventPublisher.events[0], isA<JobQueuedEvent>());
    expect(eventPublisher.events[1], isA<JobStartedEvent>());
    expect(eventPublisher.events[2], isA<JobSucceededEvent>());
  });

  test('Scheduler honors retry policy', () async {
    final worker = FailingWorker();
    scheduler.registerWorker(worker);
    
    await scheduler.submit(RetryingJob());
    
    await Future.delayed(Duration.zero);
    
    expect(worker.attempts, 2);
    expect(scheduler.monitor.retryCount, 1);
    
    // Check events: Queued -> Started -> Retrying -> Started -> Succeeded
    expect(eventPublisher.events.length, 5);
    expect(eventPublisher.events[2], isA<JobRetriedEvent>());
    expect(eventPublisher.events[4], isA<JobSucceededEvent>());
  });

  test('Scheduler handles cooperative cancellation', () async {
    final worker = LongRunningWorker();
    scheduler.registerWorker(worker);
    
    await scheduler.submit(CancellableJob());
    
    // Allow job to start
    await Future.delayed(const Duration(milliseconds: 20));
    
    expect(scheduler.monitor.activeJobCount, 1);
    
    await scheduler.cancel('job_cancel');
    
    // Allow cancellation exception to propagate
    await Future.delayed(const Duration(milliseconds: 20));
    
    expect(worker.finished, isFalse);
    expect(scheduler.monitor.activeJobCount, 0);
    expect(scheduler.monitor.cancellationCount, 1);
    
    // Check events: Queued -> Started -> Cancelled
    expect(eventPublisher.events.last, isA<JobCancelledEvent>());
  });
}
