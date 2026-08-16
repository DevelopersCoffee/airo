import 'package:flutter/foundation.dart';

import '../bridges/mind_speech_bridge.dart';
import '../library_loader.dart';
import '../llama/api/meeting_intelligence.dart' as llama_mi;
import '../llama/api/minutes.dart' as llama;
import '../whisper/api/meetings.dart' as rust;

/// Timing and memory from the most recently completed generation call.
@immutable
class GenerationStats {
  const GenerationStats({
    required this.prefillMs,
    required this.prefillTokens,
    required this.generationMs,
    required this.generatedTokens,
    required this.tokensPerSecond,
    required this.peakRssBytes,
  });

  final int prefillMs;
  final int prefillTokens;
  final int generationMs;
  final int generatedTokens;
  final double tokensPerSecond;
  final int peakRssBytes;
}

@immutable
sealed class MeetingIntelligenceEvent {
  const MeetingIntelligenceEvent();
}

final class MeetingIntelligenceEventExtracting extends MeetingIntelligenceEvent {
  const MeetingIntelligenceEventExtracting();
}

final class MeetingIntelligenceEventGenerating extends MeetingIntelligenceEvent {
  const MeetingIntelligenceEventGenerating(this.text);
  final String text;
}

final class MeetingIntelligenceEventMinutesReady extends MeetingIntelligenceEvent {
  const MeetingIntelligenceEventMinutesReady(this.text);
  final String text;
}

final class MeetingIntelligenceEventIrReady extends MeetingIntelligenceEvent {
  const MeetingIntelligenceEventIrReady({
    required this.decisions,
    required this.actionItems,
    required this.metrics,
  });

  final List<rust.MeetingDecisionRecord> decisions;
  final List<rust.MeetingActionItemRecord> actionItems;
  final List<rust.MeetingMetricRecord> metrics;
}

final class MeetingIntelligenceEventCancelled extends MeetingIntelligenceEvent {
  const MeetingIntelligenceEventCancelled();
}

@immutable
sealed class GenerationEvent {
  const GenerationEvent();
}

final class GenerationEventGenerating extends GenerationEvent {
  const GenerationEventGenerating(this.text);
  final String text;
}

final class GenerationEventMinutesReady extends GenerationEvent {
  const GenerationEventMinutesReady(this.text);
  final String text;
}

final class GenerationEventCancelled extends GenerationEvent {
  const GenerationEventCancelled();
}

rust.MeetingDecisionRecord toWhisperDecision(
  llama_mi.MeetingDecisionRecord record,
) => rust.MeetingDecisionRecord(
  id: record.id,
  statement: record.statement,
  status: switch (record.status) {
    llama_mi.MeetingDecisionStatus.proposed =>
      rust.MeetingDecisionStatus.proposed,
    llama_mi.MeetingDecisionStatus.agreed => rust.MeetingDecisionStatus.agreed,
    llama_mi.MeetingDecisionStatus.rejected =>
      rust.MeetingDecisionStatus.rejected,
    llama_mi.MeetingDecisionStatus.deferred_ =>
      rust.MeetingDecisionStatus.deferred_,
  },
  evidenceSegmentIds: record.evidenceSegmentIds,
);

rust.MeetingActionItemRecord toWhisperActionItem(
  llama_mi.MeetingActionItemRecord record,
) => rust.MeetingActionItemRecord(
  id: record.id,
  task: record.task,
  owner: record.owner,
  due: record.due,
  status: switch (record.status) {
    llama_mi.MeetingActionStatus.open => rust.MeetingActionStatus.open,
    llama_mi.MeetingActionStatus.inProgress =>
      rust.MeetingActionStatus.inProgress,
    llama_mi.MeetingActionStatus.done => rust.MeetingActionStatus.done,
    llama_mi.MeetingActionStatus.blocked =>
      rust.MeetingActionStatus.blocked,
  },
  evidenceSegmentIds: record.evidenceSegmentIds,
);

rust.MeetingMetricRecord toWhisperMetric(llama_mi.MeetingMetricRecord record) =>
    rust.MeetingMetricRecord(
      id: record.id,
      name: record.name,
      value: record.value,
      evidenceSegmentIds: record.evidenceSegmentIds,
    );

/// The generation half of the pipeline. See `MindSpeechBridge` for why this is
/// an interface rather than a direct call.
abstract interface class MindGenerationBridge {
  bool get isLoaded;

  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
    bool preferIndicGeneration = false,
    bool allowCompactFallback = true,
  });

  /// Meeting-intelligence pipeline: preprocess → extract → validate → MoM.
  Stream<MeetingIntelligenceEvent> processMeetingIntelligence({
    required String meetingId,
    required String title,
    required List<TranscriptSegment> segments,
  });

  /// Legacy prose-minutes path — retained for tests that still script it.
  Stream<GenerationEvent> generate({required String transcript, String? grammar});

  String modelId();

  GenerationStats stats();

  void unload();

  void cancel();
}

class RustMindGenerationBridge implements MindGenerationBridge {
  RustMindGenerationBridge();

  var _loaded = false;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<void> ensureLoaded({
    required String modelsDir,
    required int memoryBudgetMb,
    bool preferIndicGeneration = false,
    bool allowCompactFallback = true,
  }) async {
    await initializeLlamaBridge();
    if (llama.isReady()) {
      _loaded = true;
      return;
    }
    await llama.initialize(
      config: llama.GenerationConfig(
        modelsDir: modelsDir,
        memoryBudgetMb: memoryBudgetMb,
        preferIndicGeneration: preferIndicGeneration,
        allowCompactFallback: allowCompactFallback,
      ),
    );
    _loaded = true;
  }

  @override
  Stream<MeetingIntelligenceEvent> processMeetingIntelligence({
    required String meetingId,
    required String title,
    required List<TranscriptSegment> segments,
  }) =>
      llama_mi
          .processMeetingIntelligence(
            meetingId: meetingId,
            title: title,
            segments: [
              for (final segment in segments)
                llama_mi.MeetingIntelligenceSegment(
                  id: segment.id,
                  startMs: BigInt.from(segment.startMs),
                  endMs: BigInt.from(segment.endMs),
                  text: segment.text,
                ),
            ],
          )
          .map((event) {
            return switch (event) {
              llama_mi.MeetingIntelligenceEvent_Extracting() =>
                const MeetingIntelligenceEventExtracting(),
              llama_mi.MeetingIntelligenceEvent_Generating(:final text) =>
                MeetingIntelligenceEventGenerating(text),
              llama_mi.MeetingIntelligenceEvent_MinutesReady(:final text) =>
                MeetingIntelligenceEventMinutesReady(text),
              llama_mi.MeetingIntelligenceEvent_IrReady(
                :final decisions,
                :final actionItems,
                :final metrics,
              ) =>
                MeetingIntelligenceEventIrReady(
                  decisions: [
                    for (final decision in decisions)
                      toWhisperDecision(decision),
                  ],
                  actionItems: [
                    for (final item in actionItems) toWhisperActionItem(item),
                  ],
                  metrics: [
                    for (final metric in metrics) toWhisperMetric(metric),
                  ],
                ),
              llama_mi.MeetingIntelligenceEvent_Cancelled() =>
                const MeetingIntelligenceEventCancelled(),
            };
          });

  @override
  Stream<GenerationEvent> generate({
    required String transcript,
    String? grammar,
  }) =>
      llama
          .generateMinutes(transcript: transcript, grammar: grammar)
          .map((event) {
            return switch (event) {
              llama.GenerationEvent_Generating(:final text) =>
                GenerationEventGenerating(text),
              llama.GenerationEvent_MinutesReady(:final text) =>
                GenerationEventMinutesReady(text),
              llama.GenerationEvent_Cancelled() =>
                const GenerationEventCancelled(),
            };
          });

  @override
  String modelId() => llama.generationModelId();

  @override
  GenerationStats stats() {
    final s = llama.generationStats();
    return GenerationStats(
      prefillMs: s.prefillMs.toInt(),
      prefillTokens: s.prefillTokens,
      generationMs: s.generationMs.toInt(),
      generatedTokens: s.generatedTokens,
      tokensPerSecond: s.tokensPerSecond,
      peakRssBytes: s.peakRssBytes.toInt(),
    );
  }

  @override
  void unload() => llama.unloadGeneration();

  @override
  void cancel() {
    llama.cancelGeneration();
    llama_mi.cancelMeetingIntelligence();
  }
}
