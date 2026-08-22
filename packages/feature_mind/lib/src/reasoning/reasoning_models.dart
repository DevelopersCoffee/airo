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

  MindReasoningRequest copyWith({
    List<MindReasoningContextItem>? toolResults,
    List<String>? toolNames,
  }) {
    return MindReasoningRequest(
      userQuery: userQuery,
      intentKind: intentKind,
      intentComplexity: intentComplexity,
      requestedLevel: requestedLevel,
      maxReasoningLevel: maxReasoningLevel,
      availableMemoryMb: availableMemoryMb,
      gpuAvailable: gpuAvailable,
      npuAvailable: npuAvailable,
      thermalConstrained: thermalConstrained,
      batteryConstrained: batteryConstrained,
      memories: memories,
      documents: documents,
      toolResults: toolResults ?? this.toolResults,
      history: history,
      toolNames: toolNames ?? this.toolNames,
    );
  }
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

@immutable
class MindReasoningToolCall {
  const MindReasoningToolCall({
    required this.name,
    required this.argumentsJson,
  });

  final String name;
  final String argumentsJson;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MindReasoningToolCall &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          argumentsJson == other.argumentsJson;

  @override
  int get hashCode => Object.hash(name, argumentsJson);
}

final class MindReasoningCompleted extends MindReasoningEvent {
  const MindReasoningCompleted({
    required this.answer,
    this.reasoningSummary,
    required this.level,
    this.confidence,
    this.toolCalls = const [],
  });

  final String answer;
  final String? reasoningSummary;
  final MindReasoningLevel level;
  final double? confidence;
  final List<MindReasoningToolCall> toolCalls;
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
  String? clarificationQuestion;
  final List<String> clarificationCandidates = [];
  final List<ReasoningProgressStep> steps = [];
  final List<MindReasoningToolCall> toolCalls = [];
  IntentParserShadowCompare? shadowCompare;

  void add(MindReasoningEvent event) {
    switch (event) {
      case MindReasoningStarted():
        break;
      case MindReasoningStageChanged(:final stage):
        if (stage == MindReasoningStage.complete) return;
        steps.add(ReasoningProgressStep(label: labelForReasoningStage(stage)));
      case MindReasoningProgress(:final message):
        if (message.startsWith('level=')) return;
        if (message.startsWith(shadowProgressPrefix)) {
          shadowCompare = parseShadowProgress(message);
          if (kDebugMode) {
            debugPrint('IntentParser shadow: $message');
          }
          return;
        }
        if (message.startsWith(clarifyProgressPrefix)) {
          clarificationCandidates
            ..clear()
            ..addAll(
              message
                  .substring(clarifyProgressPrefix.length)
                  .split('|')
                  .where((id) => id.isNotEmpty),
            );
          return;
        }
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
        :final toolCalls,
      ):
        this.answer = answer;
        this.reasoningSummary = reasoningSummary;
        this.level = level;
        this.confidence = confidence;
        if (toolCalls.isNotEmpty) {
          this.toolCalls
            ..clear()
            ..addAll(toolCalls);
        }
      case MindReasoningError(:final message):
        error = message;
        if (clarificationCandidates.isNotEmpty) {
          clarificationQuestion = message;
        }
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

/// Progress payload from Rust when classify() asks instead of generating.
const clarifyProgressPrefix = 'clarify:';

/// Log-only leftover IntentParser kind vs ClassifiedIntent. Never a step.
const shadowProgressPrefix = 'shadow:';

/// Dual-run compare of the Dart leftover kind against the gated contract.
///
/// Does not route. Product intercepts keep using IntentParser; `reason()`
/// still follows `classify()`.
@immutable
class IntentParserShadowCompare {
  const IntentParserShadowCompare({
    required this.parserKind,
    required this.parserCapability,
    required this.classifiedKind,
    required this.classifiedCapability,
    required this.status,
    required this.capabilitiesMatch,
  });

  final String parserKind;
  final String parserCapability;
  final String classifiedKind;
  final String classifiedCapability;
  final String status;
  final bool capabilitiesMatch;
}

IntentParserShadowCompare? parseShadowProgress(String message) {
  if (!message.startsWith(shadowProgressPrefix)) return null;
  final parts = message.substring(shadowProgressPrefix.length).split('|');
  if (parts.length != 6) return null;
  return IntentParserShadowCompare(
    parserKind: parts[0],
    parserCapability: parts[1],
    classifiedKind: parts[2],
    classifiedCapability: parts[3],
    status: parts[4],
    capabilitiesMatch: parts[5] == '1',
  );
}

String labelForClarificationCapability(String id) {
  return switch (id) {
    'planning.create' => 'Plan my day',
    'calendar.retrieve' => 'Check my calendar',
    'skill.execute' => 'Run a skill',
    'document.summarize' => 'Summarize',
    'research.deep' => 'Research',
    _ => id,
  };
}

String followUpForClarificationCapability(String id) {
  return switch (id) {
    'planning.create' => 'Help me plan my day for tomorrow.',
    'calendar.retrieve' => "What's on my calendar tomorrow?",
    'skill.execute' => 'Create a meal plan.',
    'document.summarize' => 'Summarize the attached note.',
    'research.deep' => 'Research this for me.',
    _ => id,
  };
}
