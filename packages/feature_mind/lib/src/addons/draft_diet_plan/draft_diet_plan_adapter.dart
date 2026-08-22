import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

import '../../agent_chat/data/services/assistant_chat_context_builder.dart';
import '../../agent_chat/data/services/diet_plan_plugin_prompt.dart';
import '../../agent_chat/data/services/gguf_instruct_prompt.dart';

/// Compiled generative adapter for the Diet Plan built-in add-on.
class DraftDietPlanAdapter implements GenerativeAddonAdapter {
  DraftDietPlanAdapter();

  static const addonId = 'draft-diet-plan';

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId(addonId), version: '1.0.0');

  @override
  int? get maxOutputTokens => ggufDietPlanMaxOutputTokens;

  @override
  bool accepts(AddonConversation input) {
    return DietPlanPluginPrompt.applies(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
  }

  @override
  AddonPrompt buildPrompt(AddonConversation input) {
    final userPrompt = DietPlanPluginPrompt.modelUserPrompt(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
    return AddonPrompt(
      systemInstruction: '',
      userPrompt: userPrompt,
    );
  }

  @override
  String postProcessOutput(AddonConversation input, String output) {
    final constraints = DietPlanPluginPrompt.userConstraintLines(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
    final days = DietPlanPluginPrompt.parseDayCount(constraints.join(' '));
    return DietPlanPluginPrompt.alignPlanTitle(
      DietPlanPluginPrompt.trimExtraDays(output, days),
      days,
    );
  }

  @override
  AddonEvaluation evaluate(AddonConversation input, String output) {
    final constraints = DietPlanPluginPrompt.userConstraintLines(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
    final joined = constraints.join(' ');
    if (DietPlanPluginPrompt.isUnsafeDietRequest(joined)) {
      if (DietPlanPluginPrompt.looksLikeModelRefusal(output)) {
        return const AddonEvaluation(kind: AddonEvaluationKind.valid);
      }
      return const AddonEvaluation(
        kind: AddonEvaluationKind.invalid,
        reason: 'unsafe_diet_request',
        safeCopy:
            'I cannot help with that kind of diet restriction. Please speak with '
            'a doctor or registered dietitian.',
      );
    }
    if (DietPlanPluginPrompt.shouldRetryPlan(
      output: output,
      constraints: constraints,
    )) {
      return const AddonEvaluation(
        kind: AddonEvaluationKind.retry,
        reason: 'diet_plan_quality',
      );
    }
    return const AddonEvaluation(kind: AddonEvaluationKind.valid);
  }

  @override
  GenerationConstraint? generationConstraint(AddonConversation input) {
    final constraints = DietPlanPluginPrompt.userConstraintLines(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
    final days = DietPlanPluginPrompt.parseDayCount(constraints.join(' '));
    if (days == null) return null;
    return GenerationConstraint.forcedPrefix(
      "Here's a $days-day diet plan:\n\n",
    );
  }

  @override
  String? reliabilityRegistryKey(AddonConversation input) => 'diet_plan';

  @override
  String retryPromptSuffix(AddonConversation input) =>
      'Do not refuse. Write the meal plan now. Honor veg and allergy '
      'constraints, write every requested day, and use different dishes each day.';

  @override
  List<AddonConversationMessage> resolveContextHistory(AddonConversation input) {
    return DietPlanPluginPrompt.contextHistory(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    )
        .map(
          (message) => AddonConversationMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
  }

  @override
  List<AddonConversationMessage> collapseThreadHistory(
    List<AddonConversationMessage> history,
  ) {
    final assistantHistory = history
        .map(
          (message) => AssistantChatContextMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
    return DietPlanPluginPrompt.collapseAssistantDietDrafts(assistantHistory)
        .map(
          (message) => AddonConversationMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
  }

  @override
  List<AddonReasoningDocument> reasoningDocuments(AddonConversation input) {
    final constraints = DietPlanPluginPrompt.userConstraintLines(
      currentPrompt: input.currentPrompt,
      history: _history(input),
    );
    return [
      AddonReasoningDocument(
        source: 'diet_constraints',
        text: constraints.join('\n'),
      ),
    ];
  }

  List<AssistantChatContextMessage> _history(AddonConversation input) {
    return input.history
        .map(
          (message) => AssistantChatContextMessage(
            text: message.text,
            isUser: message.isUser,
          ),
        )
        .toList(growable: false);
  }
}
