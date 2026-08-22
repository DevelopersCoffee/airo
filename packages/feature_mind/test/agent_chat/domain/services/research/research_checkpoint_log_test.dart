import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint_log.dart';
import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/recording_operation_log.dart';

void main() {
  test(
    'appends a researchCheckpoint op whose detail is the durable record',
    () async {
      final log = RecordingOperationLog();
      const checkpoint = ResearchCheckpoint(
        jobId: 'job-1',
        question: 'What is Qwen?',
        state: ResearchPhase.paused,
        pausedFrom: ResearchPhase.searching,
        searchesUsed: 1,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
      );

      final sequence = await appendResearchCheckpointOp(
        log: log,
        checkpoint: checkpoint,
      );

      expect(sequence, 1);
      expect(log.appended.single.kind, MindOpKind.researchCheckpoint);
      expect(log.appended.single.contextId, 'job-1');
      expect(log.appended.single.detail, checkpoint.toRecord());
    },
  );

  test('latest resumable checkpoint skips completed jobs', () async {
    final log = RecordingOperationLog();
    await appendResearchCheckpointOp(
      log: log,
      checkpoint: const ResearchCheckpoint(
        jobId: 'job-old',
        question: 'Old question',
        state: ResearchPhase.paused,
        searchesUsed: 1,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
      ),
    );
    await appendResearchCheckpointOp(
      log: log,
      checkpoint: const ResearchCheckpoint(
        jobId: 'job-old',
        question: 'Old question',
        state: ResearchPhase.completed,
        searchesUsed: 2,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
      ),
    );
    await appendResearchCheckpointOp(
      log: log,
      checkpoint: const ResearchCheckpoint(
        jobId: 'job-new',
        question: 'What is Qwen?',
        state: ResearchPhase.paused,
        pausedFrom: ResearchPhase.searching,
        searchesUsed: 1,
        iterationsUsed: 1,
        completedNodeIds: ['root'],
      ),
    );

    final latest = await latestResumableResearchCheckpoint(log);
    expect(latest?.jobId, 'job-new');
    expect(latest?.question, 'What is Qwen?');
    expect(latest?.completedNodeIds, ['root']);
  });

  test(
    'newest terminal checkpoint hides older paused state for that job',
    () async {
      final log = RecordingOperationLog();
      await appendResearchCheckpointOp(
        log: log,
        checkpoint: const ResearchCheckpoint(
          jobId: 'job-finished',
          question: 'Finished question',
          state: ResearchPhase.paused,
          pausedFrom: ResearchPhase.searching,
          searchesUsed: 1,
          iterationsUsed: 1,
        ),
      );
      await appendResearchCheckpointOp(
        log: log,
        checkpoint: const ResearchCheckpoint(
          jobId: 'job-finished',
          question: 'Finished question',
          state: ResearchPhase.completed,
          searchesUsed: 2,
          iterationsUsed: 1,
        ),
      );

      expect(await latestResumableResearchCheckpoint(log), isNull);
    },
  );
}
