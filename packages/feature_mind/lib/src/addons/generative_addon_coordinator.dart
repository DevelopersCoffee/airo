import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../agent_chat/data/services/assistant_chat_context_builder.dart';

class GenerativeAddonRunPlan {
  GenerativeAddonRunPlan({
    required this.adapter,
    required this.prompt,
    required this.conversation,
  });

  final GenerativeAddonAdapter adapter;
  final AddonPrompt prompt;
  final AddonConversation conversation;

  AddonIdentity get identity => adapter.identity;

  GenerationConstraint? get constraint =>
      adapter.generationConstraint(conversation);

  int? get maxOutputTokens => adapter.maxOutputTokens;

  RegisteredPrompt? reliabilityDefinition() {
    final key = adapter.reliabilityRegistryKey(conversation);
    if (key == 'diet_plan') return AiroPromptRegistry.dietPlan;
    return null;
  }

  List<AssistantChatContextMessage> contextHistory(
    List<AssistantChatContextMessage> fullHistory,
  ) {
    return _toAssistantMessages(adapter.resolveContextHistory(conversation));
  }

  List<AssistantChatContextMessage> collapseHistory(
    List<AssistantChatContextMessage> fullHistory,
  ) {
    final thread = fullHistory
        .map(
          (message) => AddonConversationMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
    return _toAssistantMessages(adapter.collapseThreadHistory(thread));
  }

  List<AddonReasoningDocument> reasoningDocuments() =>
      adapter.reasoningDocuments(conversation);
}

List<AssistantChatContextMessage> _toAssistantMessages(
  List<AddonConversationMessage> messages,
) {
  return messages
      .map(
        (message) => AssistantChatContextMessage(
          text: message.text,
          isUser: message.isUser,
        ),
      )
      .toList(growable: false);
}

class GenerativeAddonReview {
  const GenerativeAddonReview({
    required this.output,
    required this.shouldRetry,
    required this.invalid,
  });

  final String output;
  final bool shouldRetry;
  final bool invalid;
}

/// Routes generative add-on behavior through the registry without host ID switches.
class GenerativeAddonCoordinator {
  GenerativeAddonCoordinator(this._registry);

  final AddonRegistry _registry;

  GenerativeAddonRunPlan? planFor({
    required String currentPrompt,
    required List<AssistantChatContextMessage> history,
  }) {
    final conversation = AddonConversation(
      currentPrompt: currentPrompt,
      history: [
        for (final message in history)
          AddonConversationMessage(text: message.text, isUser: message.isUser),
      ],
    );
    for (final adapter in _registry.eligibleGenerativeAdapters()) {
      if (adapter.accepts(conversation)) {
        return GenerativeAddonRunPlan(
          adapter: adapter,
          prompt: adapter.buildPrompt(conversation),
          conversation: conversation,
        );
      }
    }
    return null;
  }

  GenerativeAddonReview reviewOutput({
    required GenerativeAddonRunPlan plan,
    required String output,
    required bool alreadyRetried,
  }) {
    var processed = plan.adapter.postProcessOutput(plan.conversation, output);
    final evaluation = plan.adapter.evaluate(plan.conversation, processed);

    if (evaluation.kind == AddonEvaluationKind.invalid) {
      final safe = evaluation.safeCopy.trim();
      return GenerativeAddonReview(
        output: safe.isNotEmpty ? safe : processed,
        shouldRetry: false,
        invalid: true,
      );
    }

    if (!alreadyRetried && evaluation.wantsRetry) {
      return GenerativeAddonReview(
        output: processed,
        shouldRetry: true,
        invalid: false,
      );
    }

    if (!evaluation.isValid && evaluation.safeCopy.isNotEmpty) {
      return GenerativeAddonReview(
        output: evaluation.safeCopy,
        shouldRetry: false,
        invalid: true,
      );
    }

    return GenerativeAddonReview(
      output: processed,
      shouldRetry: false,
      invalid: false,
    );
  }

  String retryModelPrompt(GenerativeAddonRunPlan plan, String basePrompt) {
    final suffix = plan.adapter.retryPromptSuffix(plan.conversation).trim();
    if (suffix.isEmpty) return basePrompt;
    return '$basePrompt\n\n$suffix';
  }

  List<AssistantChatContextMessage> collapseThreadHistory(
    List<AssistantChatContextMessage> history,
  ) {
    var thread = history
        .map(
          (message) => AddonConversationMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
    for (final adapter in _registry.eligibleGenerativeAdapters()) {
      thread = adapter.collapseThreadHistory(thread);
    }
    return _toAssistantMessages(thread);
  }
}
