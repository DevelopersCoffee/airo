import 'package:core_domain/core_domain.dart';

import 'addon_conversation.dart';
import 'addon_evaluation.dart';
import 'addon_prompt.dart';

abstract interface class GenerativeAddonAdapter {
  AddonIdentity get identity;

  bool accepts(AddonConversation input);

  AddonPrompt buildPrompt(AddonConversation input);

  AddonEvaluation evaluate(String output);
}
