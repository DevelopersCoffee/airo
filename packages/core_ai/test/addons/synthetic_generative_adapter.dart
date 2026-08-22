import 'package:core_ai/core_ai.dart';
import 'package:core_domain/core_domain.dart';

class SyntheticGenerativeAdapter implements GenerativeAddonAdapter {
  SyntheticGenerativeAdapter({this.trigger = 'sample-trigger'});

  final String trigger;

  @override
  AddonIdentity get identity =>
      const AddonIdentity(id: AddonId('sample-generative'), version: '1.0.0');

  @override
  bool accepts(AddonConversation input) =>
      input.currentPrompt.contains(trigger);

  @override
  AddonPrompt buildPrompt(AddonConversation input) => AddonPrompt(
    systemInstruction: 'sample-system',
    userPrompt: 'prompt:${input.currentPrompt}',
  );

  @override
  AddonEvaluation evaluate(String output) {
    if (output.contains('invalid')) {
      return const AddonEvaluation(
        kind: AddonEvaluationKind.invalid,
        safeCopy: 'sample-safe-copy',
      );
    }
    return const AddonEvaluation(kind: AddonEvaluationKind.valid);
  }
}
