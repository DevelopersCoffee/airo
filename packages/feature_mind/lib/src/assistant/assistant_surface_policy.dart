import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which assistant hub tiles and chat skill chips a shell should surface.
///
/// The super-app mobile shell keeps the full gallery. The standalone Airo Mind
/// shell on desktop hides phone-only destinations (Quest image upload, mobile
/// device actions, Arena games) that this shell does not mount anyway.
class AssistantSurfacePolicy {
  const AssistantSurfacePolicy({
    this.showQuestImage = true,
    this.showMobileActions = true,
    this.showArenaGames = true,
  });

  const AssistantSurfacePolicy.mindDesktop()
    : showQuestImage = false,
      showMobileActions = false,
      showArenaGames = false;

  final bool showQuestImage;
  final bool showMobileActions;
  final bool showArenaGames;

  static const mobile = AssistantSurfacePolicy();
}

final assistantSurfacePolicyProvider = Provider<AssistantSurfacePolicy>(
  (ref) => AssistantSurfacePolicy.mobile,
);
