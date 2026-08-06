/// Entrypoint for the standalone Airo Mind shell. Pairs with
/// `pubspec_mind.yaml`.
///
/// Record a meeting, watch it transcribe, read the minutes, search what was
/// said — and ask the assistant about any of it, with no other tab in the way.
///
/// Composed the same way every other shell is: a [ModuleRegistry] scoped to
/// [ShellId.mind] owns module inclusion, routes, lifecycle, and provider
/// overrides, while this file owns only the shell's own chrome (theme, router,
/// startup). Two modules ship here:
///
/// * [MindScribeModule] — the `feature_mind` scribe journey, mounted at `/`.
/// * [AssistantModule] — the assistant hub from `feature_assistant`, mounted
///   at its canonical `/assistant` + `/wellbeing` paths, wired to the same
///   [AppAssistantHostAdapter] the super app uses.
///
/// ### Destinations this shell does not ship
///
/// The assistant package navigates by absolute super-app paths, and it must
/// not branch on which shell it is running in. The gap is closed here, at the
/// shell, in two ways:
///
/// * Paths with a real equivalent are redirected — [mindLegacyRedirects] maps
///   the pre-extraction `/agent*` aliases (still emitted by the package's tool
///   registry and route connector) onto `/assistant*`, mirroring the super
///   app's router.
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

import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_assistant/feature_assistant.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/assistant/app_assistant_host_adapter.dart';
import 'core/config/firebase_status.dart';
import 'core/mind/mind_scribe_module.dart';
import 'core/mind/mind_unavailable_screen.dart';
import 'core/pro/pro_bootstrap_runner.dart';
import 'core/routing/route_names.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebase();

  final registry = buildMindModuleRegistry();
  runApp(AiroMindApp(registry: registry));

  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(registry.initializeAll());
    unawaited(runProBootstrap());
  });
}

/// Firebase, for auth parity with the super app: the assistant's profile
/// screen signs in and out through the same [AppAssistantHostAdapter], and
/// Google Sign-In needs Firebase. Deliberately only the initialization block
/// from `main.dart` — none of its EPG or notification wiring, which belongs
/// to features this shell does not ship.
Future<void> _initializeFirebase() async {
  try {
    if (Firebase.apps.isNotEmpty) {
      isFirebaseInitialized = true;
      return;
    }
    final options = DefaultFirebaseOptions.currentPlatform;
    if (!DefaultFirebaseOptions.isCurrentPlatformConfigured ||
        !DefaultFirebaseOptions.isConfigured(options)) {
      isFirebaseInitialized = false;
      debugPrint('⚠️ Firebase not configured for this platform; skipping init');
      return;
    }
    await Firebase.initializeApp(options: options);
    isFirebaseInitialized = true;
  } catch (e) {
    isFirebaseInitialized = Firebase.apps.isNotEmpty;
    debugPrint('⚠️ Firebase initialization failed: $e');
  }
}

/// Builds the Airo Mind shell's module registry. Split out (and returning a
/// fresh instance per call) so tests exercise the exact registration this
/// entrypoint performs without sharing static state.
@visibleForTesting
ModuleRegistry buildMindModuleRegistry() {
  return ModuleRegistry(shell: ShellId.mind)
    ..register(MindScribeModule())
    ..register(
      AssistantModule(hostAdapterBuilder: AppAssistantHostAdapter.new),
    );
}

/// Pre-extraction assistant paths, mapped onto the paths this shell mounts.
///
/// `feature_assistant`'s tool registry, route connector, and chat screen still
/// answer with `/agent*`; the super app's router carries the same aliases. The
/// map is public so a test can prove the two shells agree.
@visibleForTesting
const Map<String, String> mindLegacyRedirects = <String, String>{
  '/agent': AssistantRouteNames.assistant,
  '/agent/notifications': AssistantRouteNames.notifications,
  '/agent/profile': AssistantRouteNames.profile,
  '/agent/models': AssistantRouteNames.models,
};

/// The Mind shell's complete route table: module routes, legacy aliases, and
/// the account screens the host adapter navigates to.
@visibleForTesting
List<RouteBase> buildMindRoutes(ModuleRegistry registry) => <RouteBase>[
  ...registry.allRoutes,
  for (final MapEntry<String, String> alias in mindLegacyRedirects.entries)
    GoRoute(path: alias.key, redirect: (context, state) => alias.value),
  GoRoute(
    path: RouteNames.login,
    name: RouteNames.login,
    builder: (context, state) => const LoginScreen(),
  ),
  GoRoute(
    path: RouteNames.register,
    name: RouteNames.register,
    builder: (context, state) => const RegisterScreen(),
  ),
];

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
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: widget.registry.allProviderOverrides,
      child: MaterialApp.router(
        title: 'Airo Mind',
        theme: ThemeData(useMaterial3: true),
        routerConfig: _router,
      ),
    );
  }
}
