import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
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

/// Every `/assistant/*` and `/agent/*` path a shipped deep link or a
/// notification already sitting in the OS can carry, and where it must land
/// now that `/mind` is the hub's root.
const _legacyRedirects = <String, String>{
  '/assistant': '/mind',
  '/assistant/chat': '/mind/chat',
  '/assistant/prompt-lab': '/mind/prompt-lab',
  '/assistant/audio-scribe': '/mind/audio-scribe',
  '/assistant/skills': '/mind/skills',
  '/assistant/device-capabilities': '/mind/device-capabilities',
  '/assistant/model-advisor': '/mind/model-advisor',
  '/assistant/mobile-actions': '/mind/mobile-actions',
  '/agent': '/mind',
  '/agent/notifications': '/mind/notifications',
  '/agent/profile': '/mind/profile',
  '/agent/models': '/mind/models',
  // Regression coverage for the latent bug fba57d6d found: the old `/agent`
  // block only enumerated four children, so these seven fell through to a
  // 404 despite `/agent -> /assistant` "working".
  '/agent/skills': '/mind/skills',
  '/agent/prompt-lab': '/mind/prompt-lab',
  '/agent/audio-scribe': '/mind/audio-scribe',
  '/agent/device-capabilities': '/mind/device-capabilities',
  '/agent/model-advisor': '/mind/model-advisor',
  '/agent/mobile-actions': '/mind/mobile-actions',
  '/agent/chat': '/mind/chat',
};

/// Finds the `GoRoute` in [router] whose pattern matches [location] and
/// invokes its `redirect` closure directly, returning the resolved location
/// (there is exactly one redirect hop for every path in [_legacyRedirects]).
Future<String?> _redirectFor(
  GoRouter router,
  BuildContext context,
  String location,
) async {
  final uri = Uri.parse(location);
  final path = uri.path;
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  for (final route in router.configuration.routes.whereType<GoRoute>()) {
    final routeSegments = route.path
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    if (routeSegments.length != segments.length) continue;

    final pathParameters = <String, String>{};
    var matches = true;
    for (var i = 0; i < routeSegments.length; i++) {
      final routeSegment = routeSegments[i];
      if (routeSegment.startsWith(':')) {
        // `:rest(.*)` — the parameter name is everything before an optional
        // regex in parens.
        final parenIndex = routeSegment.indexOf('(');
        final name = routeSegment.substring(
          1,
          parenIndex == -1 ? routeSegment.length : parenIndex,
        );
        pathParameters[name] = segments
            .sublist(i)
            .join('/'); // the wildcard swallows the remainder
        break;
      } else if (routeSegment != segments[i]) {
        matches = false;
        break;
      }
    }
    if (!matches || route.redirect == null) continue;

    final state = GoRouterState(
      router.configuration,
      uri: uri,
      matchedLocation: path,
      fullPath: route.path,
      pathParameters: pathParameters,
      pageKey: const ValueKey('test'),
    );
    return route.redirect!(context, state);
  }
  return null;
}

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
            'the feature_assistant extraction and the Phase 3 /mind move',
      );
    }
  });

  // These two tests call the router's own `redirect` closures directly
  // rather than driving live navigation: `AppRouter.createRouter`'s top-level
  // `redirect` awaits `AuthService.instance.initialize()` and bounces an
  // unauthenticated test session to `/login` before a per-route redirect ever
  // gets a look, which would make the assertion about auth state, not about
  // the legacy-path rewrite these tests exist to cover.
  testWidgets('legacy /assistant and /agent paths redirect to /mind', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(router.dispose);

    for (final entry in _legacyRedirects.entries) {
      final resolved = await _redirectFor(router, context, entry.key);
      expect(
        resolved,
        entry.value,
        reason: '${entry.key} must redirect to ${entry.value}',
      );
    }
  });

  testWidgets('a legacy path preserves its query string across the redirect', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final context = tester.element(find.byType(SizedBox));

    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(router.dispose);

    final resolved = await _redirectFor(
      router,
      context,
      '/assistant/chat?prefill=hello',
    );
    expect(resolved, '/mind/chat?prefill=hello');
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

  test('the router starts without the mind module and falls back to a '
      'redirect-only Mind branch (R05: web never registers it)', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)
      ..register(CoinVaultModule())
      ..register(IptvFeatureModule());

    final router = AppRouter.createRouter(moduleRegistry: registry);
    addTearDown(router.dispose);

    final branchPaths = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .expand((shell) => shell.branches)
        .expand((branch) => branch.routes)
        .whereType<GoRoute>()
        .map((route) => route.path);

    expect(branchPaths, contains(AssistantRouteNames.assistant));
    expect(
      router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      ),
      isNot(contains('/wellbeing')),
      reason:
          'Wellbeing is reached from the Mind hub; with no hub, it must '
          'not be mounted at all.',
    );
  });

  // The branch slot survives even though its contents do not. `AppShell`
  // addresses branches by `AppNavigationTab` ordinal and every `goBranch`
  // call site passes an `AppNavigationTab.index`, so a missing branch would
  // silently renumber Beats, Live, Arena, Quest and Home.
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
}
