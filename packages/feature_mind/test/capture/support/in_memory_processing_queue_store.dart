import 'package:feature_mind/src/capture/data/meeting_processing_queue_store.dart';
import 'package:feature_mind/src/capture/domain/meeting_processing_job.dart';

/// In-memory [MeetingProcessingQueueStore] whose saved list survives being
/// handed to a *new* store instance — the shape a test needs to prove
/// `MeetingProcessingQueue.restore()` really reads back what a previous
/// "process lifetime" wrote, the same restart scenario a real
/// `FileMeetingProcessingQueueStore` on disk provides.
class InMemoryProcessingQueueStore implements MeetingProcessingQueueStore {
  InMemoryProcessingQueueStore([List<MeetingProcessingJob>? seed])
    : _jobs = seed ?? [];

  List<MeetingProcessingJob> _jobs;

  @override
  Future<List<MeetingProcessingJob>> load() async => List.of(_jobs);

  @override
  Future<void> save(List<MeetingProcessingJob> jobs) async {
    _jobs = List.of(jobs);
  }
}
