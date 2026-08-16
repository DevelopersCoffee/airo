/// Entrypoint for the standalone Airo Mind shell. Pairs with
/// `pubspec_mind.yaml`.
///
/// Record a meeting, watch it transcribe, read the minutes, search what was
/// said — and ask the assistant about any of it, with no other tab in the way.
///
/// Composed the same way every other shell is: a [ModuleRegistry] scoped to
/// [ShellId.mind] owns module inclusion, routes, lifecycle, and provider
/// overrides, while this file owns only the shell's own chrome (theme, router,
/// startup). One [MindModule] ships here, carrying both halves of the
/// package (`docs/superpowers/plans/2026-08-07-airo-mind-ssot-plan.md`, Phase
/// 2): the scribe journey (mounted at `/`, since [MindModule.createService] is
/// supplied) and the assistant hub (mounted at its canonical `/mind` +
/// `/wellbeing` paths, wired to the same [AppAssistantHostAdapter] the super
/// app uses).
///
/// ### Navigating between them
///
/// The package does not link its own halves together — `MindHomeScreen`
/// renders only the scribe, and the hub links out to Wellbeing but never back
/// to the recorder — so before this shell grew a nav bar the assistant was
/// unreachable on a device (#1555). The three destinations are therefore
/// branches of a `StatefulShellRoute.indexedStack` wrapped in [MindShell]:
/// Scribe (`/`), Assistant (the hub), Models (`/models`), Wellbeing. The affordance is
/// shell-owned; `feature_mind` stays untouched. See [buildMindRoutes] for how
/// the branches are assembled from the module's three route accessors.
///
/// ### Destinations this shell does not ship
///
/// The assistant package navigates by absolute super-app paths, and it must
/// not branch on which shell it is running in. The gap is closed here, at the
/// shell, in two ways:
///
/// * Paths with a real equivalent are redirected — [mindLegacyHubRoots] lists
///   the legacy roots (`/agent`, still emitted by the package's tool registry
///   and route connector, and `/assistant`, the hub's home before Phase 3),
///   rewritten onto the current hub root, mirroring the super app's router.
/// * Everything else degrades to [MindUnavailableScreen] via the router's
///   `errorBuilder`: `/games` and `/quest/new` (assistant hub and chat
///   screen), `/money*`, `/live/*`, `/offers`, `/reader` (tool registry), and
///   `/settings` (the Settings tile on the assistant's profile screen — the
///   super app's settings hub is mostly IPTV configuration, which this shell
///   has no business showing). The assistant's own preferences stay reachable
///   in-hub through the host adapter's `aiPreferencesSection()`.
///
/// `/login` and `/register` are mounted for real, not degraded: the host
/// adapter's `signOutAndReturnToLogin` does `context.go('/login')`, so a dead
/// end there would strand a signed-out user with no way back in.
///
/// Build/run: `app/tool/run_mind_macos.sh` (flavors are separate pubspecs, so
/// selecting one means swapping the file).
library;

import 'dart:async';

import 'package:core_app_shell/core_app_shell.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/assistant/mind_assistant_host_adapter.dart';
import 'core/config/firebase_status.dart';
import 'core/error/global_error_handler.dart';
import 'core/mind/mind_models_screen.dart';
import 'core/mind/mind_model_catalog.dart';
import 'core/mind/mind_model_sources.dart';
import 'core/mind/mind_processing_queue.dart';
import 'core/mind/mind_provider_overrides.dart';
import 'core/mind/mind_shell.dart';
import 'core/mind/mind_unavailable_screen.dart';
import 'core/pro/pro_bootstrap_runner.dart';
import 'core/routing/route_names.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'firebase_options.dart';

Future<void> main() {
  late ModuleRegistry registry;
  late SharedPreferences prefs;

  return AiroBootstrap.run(
    shell: ShellId.mind,
    errorHandler: ErrorHandlerPolicy.enabled(GlobalErrorHandler.initialize),
    // Auth parity with the super app: the assistant's profile screen signs
    // in and out through the same [AppAssistantHostAdapter], and Google
    // Sign-In needs Firebase before the first frame.
    firebase: FirebasePolicy.blocking(
      options: DefaultFirebaseOptions.currentPlatform,
      isConfigured:
          DefaultFirebaseOptions.isCurrentPlatformConfigured &&
          DefaultFirebaseOptions.isConfigured(
            DefaultFirebaseOptions.currentPlatform,
          ),
      onResult: (initialized) => isFirebaseInitialized = initialized,
    ),
    composeApp: () async {
      prefs = await SharedPreferences.getInstance();
      registry = buildMindModuleRegistry();
      return ProviderScope(
        overrides: buildMindProviderOverrides(
          prefs: prefs,
          registry: registry,
        ),
        child: AiroMindApp(registry: registry),
      );
    },
    afterRunApp: () {
      scheduleDeferredStartupTask(
        debugName: 'mind_feature_initialization',
        task: registry.initializeAll,
      );
      scheduleDeferredProBootstrap();
    },
  );
}

/// Builds the Airo Mind shell's module registry. Split out (and returning a
/// fresh instance per call) so tests exercise the exact registration this
/// entrypoint performs without sharing static state.
@visibleForTesting
ModuleRegistry buildMindModuleRegistry() {
  final mind = MindModule(
    hostAdapterBuilder: MindAssistantHostAdapter.new,
    // The shell's actual default: models come from Airo's existing download
    // pipeline, not the app bundle — neither this shell nor the super app
    // ships model weights in the APK
    // (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`).
    createService: buildMindDownloadService,
    // Puts the scribe's weights in this shell's shared model explorer, read
    // from the directory the service really installs into (#1556). Contributed
    // here rather than by the package because the provider being overridden is
    // this app's, and because only this shell wants the rows — the super app's
    // model manager lists its own chat models and nothing else.
    scribeOverrides: (service) => [
      mindScribeServiceProvider.overrideWithValue(service),
      ...mindModelRegistryOverrides(modelsDirectory: service.modelsDirectory),
      // #1656: the resumable post-meeting processing queue runs the same
      // MindService instance the scribe journey uses, so a job it processes
      // lands in the one store this shell reads from.
      ...mindMeetingProcessingOverrides(service),
    ],
  );
  return ModuleRegistry(shell: ShellId.mind)..register(mind);
}

/// Legacy hub roots this shell still needs to answer: `/agent` from the
/// pre-extraction super app, and `/assistant` from before Phase 3 of the SSOT
/// plan claimed `/mind`. The super app's router carries the same aliases
/// (`app/lib/core/routing/app_router.dart`).
@visibleForTesting
const List<String> mindLegacyHubRoots = ['/agent', '/assistant'];

/// Rewrites a legacy hub prefix onto the current hub root, preserving
/// whatever follows it.
///
/// A PREFIX rewrite, not one route per destination. An earlier version of
/// this enumerated four children (notifications, profile, models, the bare
/// root) while the hub has eleven, so `/agent/prompt-lab`, `/agent/skills`
/// and the rest fell through to a 404 — the same latent bug
/// `app_router.dart`'s equivalent helper was written to fix, mirrored here.
List<GoRoute> _legacyHubRedirects(String legacyRoot) => <GoRoute>[
  GoRoute(
    path: legacyRoot,
    redirect: (context, state) => AssistantRouteNames.assistant,
  ),
  GoRoute(
    path: '$legacyRoot/:rest(.*)',
    redirect: (context, state) {
      final rest = state.pathParameters['rest'] ?? '';
      final query = state.uri.query;
      final suffix = query.isEmpty ? '' : '?$query';
      return '${AssistantRouteNames.assistant}/$rest$suffix';
    },
  ),
];

/// The Mind shell's complete route table: the navigation shell holding the
/// four destinations, the legacy aliases, and the account screens the host
/// adapter navigates to.
///
/// The three destinations are branches of a [StatefulShellRoute.indexedStack]
/// wrapped in [MindShell], so each keeps its own navigation stack and the
/// bottom bar is drawn once. That means the route table is *not*
/// `registry.allRoutes`: [MindModule] contributes three mount points and only
/// the module knows which is which, so the branches are assembled from
/// [MindModule.scribeRoutesFor], [MindModule.hubRoutesFor] and
/// [MindModule.rootRoutesFor] the same way the super app's router does it.
/// `allRoutes` still exists and is still what [ModuleRegistry] uses for
/// conflict detection — the shell just does not mount the flattened list,
/// which is what keeps `/wellbeing` from being mounted twice.
///
/// Aliases, `/login` and `/register` stay at the router's top level: they are
/// redirects and full-screen account screens, not destinations, and none of
/// them should render inside the bottom nav.
@visibleForTesting
List<RouteBase> buildMindRoutes(ModuleRegistry registry) {
  final modules = registry.registeredModules.whereType<MindModule>();
  if (modules.isEmpty) {
    throw ModuleCompositionException(
      'The Airo Mind shell requires the Mind module to be registered for '
      'shell "${registry.shell.value}".',
    );
  }
  final mind = modules.first;
  final scribeRoutes = mind.scribeRoutesFor(registry.shell);
  if (scribeRoutes.isEmpty) {
    throw ModuleCompositionException(
      'The Airo Mind shell requires the Mind module to contribute the scribe '
      'route for shell "${registry.shell.value}" — it is the shell\'s home.',
    );
  }

  return <RouteBase>[
    for (final legacyRoot in mindLegacyHubRoots)
      ..._legacyHubRedirects(legacyRoot),
    GoRoute(
      path: RouteNames.login,
      name: 'login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.register,
      name: 'register',
      builder: (context, state) => const RegisterScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MindShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(routes: scribeRoutes),
        StatefulShellBranch(routes: mind.hubRoutesFor(registry.shell)),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/models',
              name: 'mind_models',
              builder: (context, state) => const MindModelsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(routes: mind.rootRoutesFor(registry.shell)),
      ],
    ),
  ];
}

/// Builds the Mind shell's router. [initialLocation] is a seam for tests that
/// need to land on one route without walking there.
@visibleForTesting
GoRouter buildMindRouter({
  ModuleRegistry? registry,
  String initialLocation = '/',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: buildMindRoutes(registry ?? buildMindModuleRegistry()),
    errorBuilder: (context, state) =>
        MindUnavailableScreen(location: state.uri.toString()),
  );
}

/// Root widget for the Airo Mind shell.
class AiroMindApp extends StatefulWidget {
  const AiroMindApp({super.key, required this.registry});

  final ModuleRegistry registry;

  @override
  State<AiroMindApp> createState() => _AiroMindAppState();
}

class _AiroMindAppState extends State<AiroMindApp> {
  late final GoRouter _router = buildMindRouter(registry: widget.registry);

  @override
  void dispose() {
    // The registry owns module teardown, and MindModule's is real work: it
    // releases the microphone and the loaded models. `State.dispose` cannot
    // await, so this is fire-and-forget — the shell is going away either way.
    unawaited(widget.registry.disposeAll());
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Airo Mind',
      theme: AiroTheme.defaultDark,
      routerConfig: _router,
      builder: (context, child) => AiroDisplayScale(
        child: AiroDomainTheme(
          domain: AiroDomain.mind,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
