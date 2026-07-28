import 'package:platform_worker_jobs/platform_worker_jobs.dart';

import '../adapters/deterministic_search_index_provider.dart';
import '../adapters/deterministic_summary_provider.dart';
import '../domain/meeting_intelligence_contracts.dart';

typedef MeetingIntelligenceProgressCallback =
    void Function(MeetingIntelligenceStageProgress progress);

class MeetingIntelligenceJobResult {
  MeetingIntelligenceJobResult({
    required Map<MeetingIntelligenceStage, MeetingIntelligenceStageOutcome>
    outcomes,
    this.summary,
    this.searchIndex,
    this.embedding,
  }) : outcomes = Map.unmodifiable(outcomes);

  final Map<MeetingIntelligenceStage, MeetingIntelligenceStageOutcome> outcomes;
  final MeetingSummaryProjection? summary;
  final MeetingSearchIndexProjection? searchIndex;
  final MeetingEmbeddingProjection? embedding;

  MeetingIntelligenceStageOutcome outcomeFor(MeetingIntelligenceStage stage) {
    final outcome = outcomes[stage];
    if (outcome == null) {
      throw StateError('No outcome exists for ${stage.stableId}.');
    }
    return outcome;
  }
}

class MeetingIntelligenceCoordinator {
  const MeetingIntelligenceCoordinator({
    required this.executor,
    this.summaryProvider,
    this.searchIndexProvider,
    this.embeddingProvider,
  });

  const MeetingIntelligenceCoordinator.deterministic({this.embeddingProvider})
    : executor = const AiroWorkerExecutor(),
      summaryProvider = const DeterministicMeetingSummaryProvider(),
      searchIndexProvider = const DeterministicMeetingSearchIndexProvider();

  const MeetingIntelligenceCoordinator.inline({
    this.summaryProvider,
    this.searchIndexProvider,
    this.embeddingProvider,
  }) : executor = const AiroWorkerExecutor(forceInline: true);

  final AiroWorkerExecutor executor;
  final MeetingSummaryStageProvider? summaryProvider;
  final MeetingSearchIndexStageProvider? searchIndexProvider;
  final MeetingEmbeddingStageProvider? embeddingProvider;

  Future<MeetingIntelligenceJobResult> run(
    MeetingIntelligenceJobRequest request, {
    MeetingIntelligenceCancellationSignal? cancellation,
    MeetingIntelligenceProgressCallback? onProgress,
  }) async {
    final stages = [
      for (final stage in MeetingIntelligenceStage.values)
        if (request.stages.contains(stage)) stage,
    ];
    final outcomes =
        <MeetingIntelligenceStage, MeetingIntelligenceStageOutcome>{};
    MeetingSummaryProjection? summary;
    MeetingSearchIndexProjection? searchIndex;
    MeetingEmbeddingProjection? embedding;

    for (final stage in stages) {
      onProgress?.call(
        MeetingIntelligenceStageProgress(
          stage: stage,
          state: MeetingIntelligenceStageState.queued,
        ),
      );
    }

    for (final stage in stages) {
      if (cancellation?.isCancelled ?? false) {
        final outcome = MeetingIntelligenceStageOutcome.cancelled(stage: stage);
        outcomes[stage] = outcome;
        onProgress?.call(MeetingIntelligenceStageProgress.fromOutcome(outcome));
        continue;
      }

      onProgress?.call(
        MeetingIntelligenceStageProgress(
          stage: stage,
          state: MeetingIntelligenceStageState.running,
        ),
      );

      late final MeetingIntelligenceStageOutcome outcome;
      try {
        switch (stage) {
          case MeetingIntelligenceStage.summary:
            final provider = summaryProvider;
            if (provider == null) {
              outcome = MeetingIntelligenceStageOutcome.unavailable(
                stage: stage,
              );
            } else {
              summary = await executor.run(
                debugName: 'meeting-${stage.stableId}',
                kind: stage.workerJobKind,
                computation: () => provider.process(request),
              );
              outcome = MeetingIntelligenceStageOutcome.completed(stage: stage);
            }
          case MeetingIntelligenceStage.searchIndexing:
            final provider = searchIndexProvider;
            if (provider == null) {
              outcome = MeetingIntelligenceStageOutcome.unavailable(
                stage: stage,
              );
            } else {
              searchIndex = await executor.run(
                debugName: 'meeting-${stage.stableId}',
                kind: stage.workerJobKind,
                computation: () => provider.process(request),
              );
              outcome = MeetingIntelligenceStageOutcome.completed(stage: stage);
            }
          case MeetingIntelligenceStage.embedding:
            final provider = embeddingProvider;
            if (provider == null) {
              outcome = MeetingIntelligenceStageOutcome.unavailable(
                stage: stage,
              );
            } else {
              // Method channels cannot be invoked from a spawned Dart isolate.
              // The platform provider owns the native worker boundary.
              final providerResult = await provider.process(request);
              switch (providerResult) {
                case MeetingEmbeddingProviderSuccess(:final projection):
                  embedding = projection;
                  outcome = MeetingIntelligenceStageOutcome.completed(
                    stage: stage,
                  );
                case MeetingEmbeddingProviderFailure(:final code):
                  outcome = _embeddingOutcome(stage, code);
              }
            }
          case MeetingIntelligenceStage.speakerClustering:
          case MeetingIntelligenceStage.memoryUpdate:
            outcome = MeetingIntelligenceStageOutcome.unavailable(stage: stage);
        }
      } catch (_) {
        outcome = MeetingIntelligenceStageOutcome.failed(
          stage: stage,
          code: MeetingIntelligenceOutcomeCode.workerFailure,
        );
      }

      outcomes[stage] = outcome;
      onProgress?.call(MeetingIntelligenceStageProgress.fromOutcome(outcome));
    }

    return MeetingIntelligenceJobResult(
      outcomes: outcomes,
      summary: summary,
      searchIndex: searchIndex,
      embedding: embedding,
    );
  }

  static MeetingIntelligenceStageOutcome _embeddingOutcome(
    MeetingIntelligenceStage stage,
    MeetingIntelligenceOutcomeCode code,
  ) {
    return switch (code) {
      MeetingIntelligenceOutcomeCode.providerUnavailable =>
        MeetingIntelligenceStageOutcome.unavailable(stage: stage),
      MeetingIntelligenceOutcomeCode.cancelled =>
        MeetingIntelligenceStageOutcome.cancelled(stage: stage),
      MeetingIntelligenceOutcomeCode.invalidInput ||
      MeetingIntelligenceOutcomeCode.workerFailure =>
        MeetingIntelligenceStageOutcome.failed(stage: stage, code: code),
      MeetingIntelligenceOutcomeCode.completed ||
      MeetingIntelligenceOutcomeCode.persistenceFailure =>
        MeetingIntelligenceStageOutcome.failed(
          stage: stage,
          code: MeetingIntelligenceOutcomeCode.workerFailure,
        ),
    };
  }
}
