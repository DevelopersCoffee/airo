import 'package:core_domain/core_domain.dart';

import 'addon_conversation.dart';
import 'addon_evaluation.dart';
import 'addon_prompt.dart';

import '../generation/generation_constraint.dart';

/// Optional reasoning-loop context supplied by a generative add-on.
class AddonReasoningDocument {
  const AddonReasoningDocument({required this.source, required this.text});

  final String source;
  final String text;
}

abstract interface class GenerativeAddonAdapter {
  AddonIdentity get identity;

  bool accepts(AddonConversation input);

  AddonPrompt buildPrompt(AddonConversation input);

  AddonEvaluation evaluate(AddonConversation input, String output);

  String postProcessOutput(AddonConversation input, String output) => output;

  GenerationConstraint? generationConstraint(AddonConversation input) => null;

  int? get maxOutputTokens => null;

  /// When set, chat reliability uses this registry entry (e.g. `diet_plan`).
  String? reliabilityRegistryKey(AddonConversation input) => null;

  String retryPromptSuffix(AddonConversation input) => '';

  List<AddonConversationMessage> resolveContextHistory(AddonConversation input) =>
      input.history;

  List<AddonConversationMessage> collapseThreadHistory(
    List<AddonConversationMessage> history,
  ) => history;

  List<AddonReasoningDocument> reasoningDocuments(AddonConversation input) =>
      const [];
}

/// Default implementations for optional generative adapter hooks.
abstract base class GenerativeAddonAdapterStub implements GenerativeAddonAdapter {
  @override
  String postProcessOutput(AddonConversation input, String output) => output;

  @override
  GenerationConstraint? generationConstraint(AddonConversation input) => null;

  @override
  int? get maxOutputTokens => null;

  @override
  String? reliabilityRegistryKey(AddonConversation input) => null;

  @override
  String retryPromptSuffix(AddonConversation input) => '';

  @override
  List<AddonConversationMessage> resolveContextHistory(
    AddonConversation input,
  ) => input.history;

  @override
  List<AddonConversationMessage> collapseThreadHistory(
    List<AddonConversationMessage> history,
  ) => history;

  @override
  List<AddonReasoningDocument> reasoningDocuments(AddonConversation input) =>
      const [];
}
