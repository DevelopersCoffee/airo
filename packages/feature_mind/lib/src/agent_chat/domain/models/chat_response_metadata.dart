import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

import 'agent_skill.dart';

@immutable
class ChatResponseMetadata {
  const ChatResponseMetadata({
    required this.title,
    required this.runtime,
    required this.executionMode,
    required this.recordedAt,
    required this.totalDurationMs,
    this.modelId,
    this.timeToFirstTokenMs,
    this.promptTokens,
    this.completionTokens,
    this.tokensPerSecond,
    this.finishReason,
    this.toolCount,
    this.systemPromptPreview,
    this.promptPreview,
    this.responsePreview,
  });

  final String title;
  final String runtime;
  final String executionMode;
  final DateTime recordedAt;
  final int totalDurationMs;
  final String? modelId;
  final int? timeToFirstTokenMs;
  final int? promptTokens;
  final int? completionTokens;
  final double? tokensPerSecond;
  final String? finishReason;
  final int? toolCount;
  final String? systemPromptPreview;
  final String? promptPreview;
  final String? responsePreview;

  int? get totalTokens => promptTokens != null && completionTokens != null
      ? promptTokens! + completionTokens!
      : null;
}

ChatResponseMetadata buildRuntimeChatResponseMetadata({
  required String title,
  required String runtime,
  required String executionMode,
  required String prompt,
  required String response,
  required int totalDurationMs,
  required DateTime recordedAt,
  String? modelId,
  int? timeToFirstTokenMs,
  int? promptTokens,
  int? completionTokens,
  double? tokensPerSecond,
  String? finishReason,
  String? systemPromptPreview,
  String? promptPreview,
  String? responsePreview,
}) {
  return ChatResponseMetadata(
    title: title,
    runtime: runtime,
    executionMode: executionMode,
    recordedAt: recordedAt,
    totalDurationMs: totalDurationMs,
    modelId: modelId,
    timeToFirstTokenMs: timeToFirstTokenMs,
    promptTokens: promptTokens ?? TokenCounter.estimate(prompt),
    completionTokens: completionTokens ?? TokenCounter.estimate(response),
    tokensPerSecond: tokensPerSecond,
    finishReason: finishReason ?? 'stop',
    systemPromptPreview: systemPromptPreview,
    promptPreview: promptPreview,
    responsePreview: responsePreview,
  );
}

ChatResponseMetadata buildSkillChatResponseMetadata({
  required List<AgentActionTrace> traces,
  required int totalDurationMs,
  DateTime? recordedAt,
}) {
  final toolCount = traces
      .where((trace) => trace.title == 'Execute action')
      .length;
  return ChatResponseMetadata(
    title: 'Agent Skills',
    runtime: 'Local skill orchestration',
    executionMode: 'Local',
    recordedAt: recordedAt ?? DateTime.now(),
    totalDurationMs: totalDurationMs,
    toolCount: toolCount,
    finishReason: 'completed',
  );
}
