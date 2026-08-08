import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:airo_app/features/iptv/iptv_feature_module.dart';

/// The Mind tab's route **names**, exactly as the super app declared them
/// inline before `feature_assistant` was extracted (and later merged into
/// `feature_mind`). Deep links, notification payloads, and `goNamed` call
/// sites resolve on these, so every move is only correct if every one of them
/// still resolves.
///
/// The locations are read off [AssistantRouteNames] rather than written out:
/// the hub's root deliberately moved once (Phase 3 claimed `/mind` for its
/// owner), so a literal here would assert the opposite of what the package
/// declares. The names are what must not drift, and they are literals for
/// exactly that reason.
final _preExtractionAssistantRoutes = <String, String>{
  'Assistant': AssistantRouteNames.assistant,
  'assistant_chat': AssistantRouteNames.chat,
  'agent_notifications': AssistantRouteNames.notifications,
  'profile': AssistantRouteNames.profile,
  'assistant_models': AssistantRouteNames.models,
  'assistant_device_capabilities': AssistantRouteNames.deviceCapabilities,
  'assistant_model_advisor': AssistantRouteNames.modelAdvisor,
  'assistant_prompt_lab': AssistantRouteNames.promptLab,
  'assistant_audio_scribe': AssistantRouteNames.audioScribe,
  'assistant_agent_skills': AssistantRouteNames.agentSkills,
  'assistant_mobile_actions': AssistantRouteNames.mobileActions,
  'Wellbeing': AssistantRouteNames.wellbeing,
};

void main() {
  test('every assistant route survives the feature_assistant extraction', () {
    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(router.dispose);

    for (final entry in _preExtractionAssistantRoutes.entries) {
      expect(
        router.namedLocation(entry.key),
        entry.value,
        reason:
            'route "${entry.key}" must still resolve to ${entry.value} after '
            'the feature_assistant extraction',
      );
    }
  });

  test('wellbeing stays outside the Mind navigation branch', () {
    final registry = buildMainModuleRegistry();
    final router = AppRouter.createRouter(moduleRegistry: registry);
    addTearDown(router.dispose);

    // Mounting Wellbeing inside the branch would keep the location working
    // while silently wrapping a full-screen destination in the bottom nav, so
    // assert on the mount point rather than only on the name.
    final branchPaths = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .expand((shell) => shell.branches)
        .expand((branch) => branch.routes)
        .whereType<GoRoute>()
        .map((route) => route.path);

    expect(branchPaths, contains(AssistantRouteNames.assistant));
    expect(branchPaths, isNot(contains(AssistantRouteNames.wellbeing)));
    expect(
      router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      ),
      contains('/wellbeing'),
    );
  });

  test('the router refuses to start without the mind module', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)
      ..register(CoinVaultModule())
      ..register(IptvFeatureModule());

    expect(
      () => AppRouter.createRouter(moduleRegistry: registry),
      throwsA(
        isA<ModuleCompositionException>().having(
          (error) => error.message,
          'message',
          contains('mind'),
        ),
      ),
    );
  });
}
