import 'package:core_ai/core_ai.dart';
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
    ref.keepAlive();
    final path = await _processingQueuePath();
    late final MeetingProcessingQueue queue;
    final runner = MeetingProcessingJobRunner(
      mindService: service,
      retentionPolicy: () => ref.read(audioRetentionPolicyProvider),
      languageMode: () => ref.read(speechLanguageModeProvider),
      processingProfile: () => ref.read(processingProfileProvider),
      onProgress: (job, progress) => queue.reportProgress(job.id, progress),
      onProcessed: (job, last) async {
        final capability = await openNotebookCapability();
        await NotebookRepository(capability).ingestProcessed(
          job: job,
          transcript: last.transcript,
          minutes: last.minutes,
          meetingId: last.meetingId,
          languageCode: ref
              .read(speechLanguageModeProvider)
              .processLanguageCode,
        );
      },
    );
    queue = MeetingProcessingQueue(
      store: FileMeetingProcessingQueueStore(path),
      // No real free-disk-space probe exists in this codebase yet -- see
      // `RealLlmDeviceSignalsProbe.availableStorageMb`'s doc comment and
      // `meeting_capture_providers.dart`'s matching note. Thermal pressure,
      // the signal this queue actually gates on, does not depend on it.
      deviceSignalsProbe: RealLlmDeviceSignalsProbe(
        availableStorageMb: () async => 4096,
      ),
      processJob: runner.call,
      // chief-security-officer review (#1656): a job that exhausts its
      // retry budget must still honour a delete-after-transcript policy --
      // see `MeetingProcessingJobRunner.cleanupAfterTerminalFailure`'s doc.
      onTerminalFailure: runner.cleanupAfterTerminalFailure,
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
