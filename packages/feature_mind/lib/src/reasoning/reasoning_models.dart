import 'package:flutter/foundation.dart';

/// How hard this request is allowed to think. Dart mirror of the Rust
/// capability enum — policy still runs in Rust.
enum MindReasoningLevel { none, light, standard, deep }

enum MindReasoningStage {
  understanding,
  retrievingContext,
  usingTool,
  analyzing,
  validating,
  composingAnswer,
  complete,
}

@immutable
class MindReasoningContextItem {
  const MindReasoningContextItem({required this.source, required this.text});

  final String source;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindReasoningContextItem &&
          runtimeType == other.runtimeType &&
          source == other.source &&
          text == other.text;

  @override
  int get hashCode => Object.hash(source, text);
}

/// Flutter-facing request. Intent kind + complexity are a classified
/// result, not a keyword search. Device fields are host probes; Rust
/// never inspects the OS.
@immutable
class MindReasoningRequest {
  const MindReasoningRequest({
    required this.userQuery,
    required this.intentKind,
    this.intentComplexity = 0,
    this.requestedLevel,
    this.maxReasoningLevel = MindReasoningLevel.deep,
    this.availableMemoryMb = 8192,
    this.gpuAvailable = true,
    this.npuAvailable = false,
    this.thermalConstrained = false,
    this.batteryConstrained = false,
    this.memories = const [],
    this.documents = const [],
    this.toolResults = const [],
    this.history = const [],
    this.toolNames = const [],
  });

  final String userQuery;
  final String intentKind;
  final double intentComplexity;
  final MindReasoningLevel? requestedLevel;
  final MindReasoningLevel maxReasoningLevel;
  final int availableMemoryMb;
  final bool gpuAvailable;
  final bool npuAvailable;
  final bool thermalConstrained;
  final bool batteryConstrained;
  final List<MindReasoningContextItem> memories;
  final List<MindReasoningContextItem> documents;
  final List<MindReasoningContextItem> toolResults;
  final List<MindReasoningContextItem> history;
  final List<String> toolNames;
}

@immutable
sealed class MindReasoningEvent {
  const MindReasoningEvent();
}

final class MindReasoningStarted extends MindReasoningEvent {
  const MindReasoningStarted();
}

final class MindReasoningStageChanged extends MindReasoningEvent {
  const MindReasoningStageChanged(this.stage);
  final MindReasoningStage stage;
}

final class MindReasoningProgress extends MindReasoningEvent {
  const MindReasoningProgress(this.message);
  final String message;
}

final class MindReasoningToolStarted extends MindReasoningEvent {
  const MindReasoningToolStarted(this.tool);
  final String tool;
}

final class MindReasoningToolCompleted extends MindReasoningEvent {
  const MindReasoningToolCompleted(this.tool);
  final String tool;
}

final class MindReasoningAnswerDelta extends MindReasoningEvent {
  const MindReasoningAnswerDelta(this.text);
  final String text;
}

final class MindReasoningCompleted extends MindReasoningEvent {
  const MindReasoningCompleted({
    required this.answer,
    this.reasoningSummary,
    required this.level,
    this.confidence,
  });

  final String answer;
  final String? reasoningSummary;
  final MindReasoningLevel level;
  final double? confidence;
}

final class MindReasoningError extends MindReasoningEvent {
  const MindReasoningError(this.message);
  final String message;
}

final class MindReasoningCancelled extends MindReasoningEvent {
  const MindReasoningCancelled();
}

@immutable
class ReasoningProgressStep {
  const ReasoningProgressStep({required this.label, this.detail});

  final String label;
  final String? detail;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReasoningProgressStep &&
          runtimeType == other.runtimeType &&
          label == other.label &&
          detail == other.detail;

  @override
  int get hashCode => Object.hash(label, detail);
}

/// Accumulates a reasoning stream for the chat bubble. Answer tokens live
/// on [answer]; progress steps never include the envelope or a thought
/// trace.
class ReasoningStreamFold {
  String answer = '';
  String? reasoningSummary;
  MindReasoningLevel? level;
  double? confidence;
  String? error;
  var cancelled = false;
  final List<ReasoningProgressStep> steps = [];

  void add(MindReasoningEvent event) {
    switch (event) {
      case MindReasoningStarted():
        break;
      case MindReasoningStageChanged(:final stage):
        if (stage == MindReasoningStage.complete) return;
        steps.add(ReasoningProgressStep(label: labelForReasoningStage(stage)));
      case MindReasoningProgress(:final message):
        if (message.startsWith('level=')) return;
        steps.add(ReasoningProgressStep(label: message));
      case MindReasoningToolStarted(:final tool):
        steps.add(ReasoningProgressStep(label: 'Using $tool'));
      case MindReasoningToolCompleted(:final tool):
        steps.add(ReasoningProgressStep(label: 'Finished $tool'));
      case MindReasoningAnswerDelta(:final text):
        answer += text;
      case MindReasoningCompleted(
        :final answer,
        :final reasoningSummary,
        :final level,
        :final confidence,
      ):
        this.answer = answer;
        this.reasoningSummary = reasoningSummary;
        this.level = level;
        this.confidence = confidence;
      case MindReasoningError(:final message):
        error = message;
      case MindReasoningCancelled():
        cancelled = true;
    }
  }
}

String labelForReasoningStage(MindReasoningStage stage) {
  return switch (stage) {
    MindReasoningStage.understanding => 'Reading your request',
    MindReasoningStage.retrievingContext => 'Gathering context',
    MindReasoningStage.usingTool => 'Using a tool',
    MindReasoningStage.analyzing => 'Working through it',
    MindReasoningStage.validating => 'Checking the answer',
    MindReasoningStage.composingAnswer => 'Writing an answer',
    MindReasoningStage.complete => 'Done',
  };
}
