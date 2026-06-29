import 'package:flutter_riverpod/flutter_riverpod.dart';
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
