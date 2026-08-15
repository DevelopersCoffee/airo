import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Wires #1656's resumable post-meeting processing queue to this shell's real
/// [MindService] — the same instance [buildMindDownloadService] built for the
/// scribe journey, so a job the queue processes lands in the same store the
/// rest of Airo Mind reads from.
///
/// Mirrors [mindModelRegistryOverrides]'s shape: a `List<Override>` built
/// from the already-constructed [MindService], contributed at the shell's
/// composition root because `feature_mind`'s own
/// `meetingProcessingQueueProvider` deliberately ships with no real
/// `processJob` (see that provider's doc comment) — only the app knows which
/// `MindService` instance is "the" one.
List<Override> mindMeetingProcessingOverrides(MindService service) => [
  meetingProcessingQueueProvider.overrideWith((ref) async {
    final path = await _processingQueuePath();
    final retentionPolicyState = ref.watch(audioRetentionPolicyProvider);
    final runner = MeetingProcessingJobRunner(
      mindService: service,
      // A closure that reads current Riverpod state, not the value at
      // override time -- ref.watch above only re-creates the queue when the
      // toggle flips, but `MeetingProcessingJobRunner` reads this per job it
      // runs, so a job that finishes long after the toggle changed still
      // gets today's answer.
      retentionPolicy: () => ref.read(audioRetentionPolicyProvider),
    );
    final queue = MeetingProcessingQueue(
      store: FileMeetingProcessingQueueStore(path),
      // No real free-disk-space probe exists in this codebase yet -- see
      // `RealLlmDeviceSignalsProbe.availableStorageMb`'s doc comment and
      // `meeting_capture_providers.dart`'s matching note. Thermal pressure,
      // the signal this queue actually gates on, does not depend on it.
      deviceSignalsProbe: RealLlmDeviceSignalsProbe(
        availableStorageMb: () async => 4096,
      ),
      processJob: runner.call,
    );
    ref.onDispose(() {
      // ignore: discarded_futures
      queue.dispose();
    });
    await queue.restore();
    return queue;
  }),
];

/// Same base directory `nextMeetingRecordingPath()`
/// (`capture/application/meeting_capture_providers.dart`) writes recordings
/// into -- the queue file lives next to the audio it tracks.
Future<String> _processingQueuePath() async {
  final dir = await getApplicationSupportDirectory();
  return p.join(dir.path, 'mind_recordings', 'processing_queue.json');
}
