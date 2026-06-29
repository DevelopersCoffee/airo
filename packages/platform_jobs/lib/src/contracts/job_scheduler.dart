import 'job.dart';
import 'job_worker.dart';
import 'job_monitor.dart';

abstract interface class JobScheduler {
  JobMonitor get monitor;
  
  void registerWorker(JobWorker worker);
  
  Future<void> submit(Job job);
  
  Future<void> cancel(String jobId);
}
