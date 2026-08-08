import 'package:airo_app/core/providers/navigation_provider.dart';
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

  // Mind was a hard requirement here until R05 made it a composition choice:
  // `core/mind/register_mind_module_web.dart` registers nothing, so a web
  // build reaches this router with exactly the registry below. Requiring the
  // module would compile clean and then throw before the first frame — the
  // failure mode this test now exists to catch, inverted.
  test('the router starts without the mind module', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)
      ..register(CoinVaultModule())
      ..register(IptvFeatureModule());

    final router = AppRouter.createRouter(moduleRegistry: registry);
    addTearDown(router.dispose);

    expect(router.configuration.routes, isNotEmpty);
  });

  test('a router without the mind module offers no Mind destination', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)
      ..register(CoinVaultModule())
      ..register(IptvFeatureModule());
    final router = AppRouter.createRouter(moduleRegistry: registry);
    addTearDown(router.dispose);

    final allPaths = [
      ...router.configuration.routes.whereType<GoRoute>().map((r) => r.path),
      ...router.configuration.routes
          .whereType<StatefulShellRoute>()
          .expand((shell) => shell.branches)
          .expand((branch) => branch.routes)
          .whereType<GoRoute>()
          .map((r) => r.path),
    ];

    // The hub root and Wellbeing must not resolve: absent, not disabled.
    expect(allPaths, isNot(contains(AssistantRouteNames.assistant)));
    expect(allPaths, isNot(contains(AssistantRouteNames.wellbeing)));
    for (final name in _preExtractionAssistantRoutes.keys) {
      expect(
        () => router.namedLocation(name),
        throwsAssertionError,
        reason: 'route "$name" must not resolve on a build without Mind',
      );
    }
  });

  // The branch slot survives even though its contents do not. `AppShell`
  // addresses branches by `AppNavigationTab` ordinal, so a missing branch
  // would renumber Beats, Live, Arena, Quest and Home.
  test('the mind branch keeps its slot when the module is absent', () {
    final withMind = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(withMind.dispose);
    final withoutMind = AppRouter.createRouter(
      moduleRegistry: ModuleRegistry(shell: ShellId.mobile)
        ..register(CoinVaultModule())
        ..register(IptvFeatureModule()),
    );
    addTearDown(withoutMind.dispose);

    int branchCount(GoRouter router) => router.configuration.routes
        .whereType<StatefulShellRoute>()
        .expand((shell) => shell.branches)
        .length;

    expect(branchCount(withoutMind), branchCount(withMind));
  });

  test('the nav policy drops the Assistant tab when Mind is absent', () {
    final policy = appNavigationPolicy.without(AppNavigationTab.assistant);

    expect(
      policy.compactPrimaryTabs,
      isNot(contains(AppNavigationTab.assistant)),
    );
    expect(policy.widePrimaryTabs, isNot(contains(AppNavigationTab.assistant)));
    expect(policy.overflowTabs, isNot(contains(AppNavigationTab.assistant)));
    // Everything else is untouched — this removes a destination, not a policy.
    expect(policy.compactPrimaryTabs, contains(AppNavigationTab.coins));
    expect(
      policy.widePrimaryTabs.length,
      appNavigationPolicy.widePrimaryTabs.length - 1,
    );
    expect(
      policy.compactWidthBreakpoint,
      appNavigationPolicy.compactWidthBreakpoint,
    );
  });
}
