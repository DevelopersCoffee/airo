import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/airo_explore/presentation/screens/airo_explore_screen.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import '../../features/settings/presentation/screens/airo_portability_screen.dart';
import '../../features/games/presentation/screens/games_hub_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/music/presentation/screens/music_screen.dart';
import '../../features/quest/presentation/screens/quest_chat_screen.dart';
import '../../features/quest/presentation/screens/quest_list_screen.dart';
import '../../features/quest/presentation/screens/quest_upload_screen.dart';
import '../../features/coins/presentation/screens/coins_dashboard_screen.dart';
import '../../features/coins/presentation/screens/add_expense_screen.dart';
import '../../features/coins/presentation/screens/budget_management_screen.dart';
import '../../features/coins/presentation/screens/groups_list_screen.dart';
import '../../features/coins/presentation/screens/group_detail_screen.dart';
import '../../features/coins/presentation/screens/add_split_expense_screen.dart';
import '../../features/life_track/presentation/screens/track_detail_screen.dart';
import '../../features/life_track/presentation/screens/track_list_screen.dart';
import '../../core/auth/auth_service.dart';
import '../../core/app/app_shell.dart';
import '../http/http_dog.dart';
import 'route_names.dart';

class AppRouter {
  // Private constructor to prevent instantiation
  AppRouter._();

  static GoRouter createRouter({
    required ModuleRegistry moduleRegistry,
    String initialLocation = '/money',
  }) {
    if (moduleRegistry.shell != ShellId.mobile) {
      throw ArgumentError.value(
        moduleRegistry.shell,
        'moduleRegistry.shell',
        'The super-app router requires ShellId.mobile.',
      );
    }
    final coinVaultRoutes = _requiredModuleRoutes(moduleRegistry, 'coin_vault');
    final iptvRoutes = _requiredModuleRoutes(moduleRegistry, 'iptv');
    // The assistant is read as a module instance rather than as a flat route
    // bundle: it owns two mount points (the Mind branch and a top-level
    // destination), and the module names them so the router does not have to
    // re-derive the split from route paths.
    //
    // Optional, not required: R05 keeps Mind off shared surfaces (web) by
    // never registering it there (`main.dart`'s conditional import), and this
    // router is the one entrypoint every surface shares. A missing module is
    // a legitimate composition, not a startup failure -- see
    // `_mindAbsentHubRoutes` for what the Mind branch renders instead.
    final assistant = _optionalModule<MindModule>(moduleRegistry, 'mind');

    return GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) async {
        // Initialize auth service if not already done
        await AuthService.instance.initialize();

        final isLoggedIn = AuthService.instance.isLoggedIn;
        final isLoginRoute =
            state.matchedLocation == RouteNames.login ||
            state.matchedLocation == RouteNames.register;

        // If not logged in and not on login/register page, redirect to login
        if (!isLoggedIn && !isLoginRoute) {
          return RouteNames.login;
        }

        // If logged in and on login page, redirect to the finance dashboard.
        if (isLoggedIn && isLoginRoute) {
          return '/money';
        }

        return null; // No redirect needed
      },
      routes: [
        // Redirect root to finance dashboard.
        GoRoute(path: '/', redirect: (context, state) => '/money'),
        // Legacy hub roots. The hub lives at `/mind` from Phase 3 of the SSOT
        // plan; `/agent` and `/assistant` are both previous homes and both
        // still appear in shipped deep links and in notifications sitting in
        // the OS.
        //
        // A PREFIX rewrite, not a route per destination. The `/agent` block
        // this replaces enumerated four children while the hub has eleven, so
        // `/agent/prompt-lab`, `/agent/audio-scribe`, `/agent/skills` and the
        // rest fell through to a 404. Enumerating is how that drifted, and it
        // would drift again the next time a destination is added.
        ..._legacyHubRedirects('/agent'),
        ..._legacyHubRedirects('/assistant'),
        // Assistant destinations that are reached from the Mind hub but are
        // not part of it (Wellbeing), so they render full-screen instead of
        // inside the bottom nav. Absent entirely when Mind itself is absent
        // (web) -- there is no hub for them to be reached from.
        if (assistant != null) ...assistant.rootRoutesFor(moduleRegistry.shell),
        GoRoute(path: '/beats', redirect: (context, state) => '/music'),
        GoRoute(path: '/stream', redirect: (context, state) => '/iptv'),
        GoRoute(
          path: '/airo/iptv',
          redirect: (context, state) => Uri(
            path: '/iptv',
            queryParameters: state.uri.queryParameters,
          ).toString(),
        ),
        GoRoute(path: '/live', redirect: (context, state) => '/music'),
        GoRoute(path: '/live/music', redirect: (context, state) => '/music'),
        GoRoute(path: '/live/tv', redirect: (context, state) => '/iptv'),
        GoRoute(
          path: '/life-track',
          name: 'life_track',
          builder: (context, state) => const TrackListScreen(),
          routes: [
            GoRoute(
              path: ':trackId',
              name: 'life_track_detail',
              builder: (context, state) =>
                  TrackDetailScreen(trackId: state.pathParameters['trackId']!),
            ),
          ],
        ),
        GoRoute(
          path: '/airo-explore',
          name: 'airo_explore',
          builder: (context, state) => const AiroExploreScreen(),
        ),
        // Settings is a plain pushed route (not a shell branch/persistent
        // tab): its only entry point is the "Settings" ListTile on
        // ProfileScreen (`context.push(RouteNames.settings)`).
        GoRoute(
          path: RouteNames.settings,
          name: RouteNames.settings,
          builder: (context, state) => const SettingsHubScreen(),
          routes: [
            GoRoute(
              path: 'airo-portability',
              name: 'airo_portability',
              builder: (context, state) => const AiroPortabilityScreen(),
            ),
          ],
        ),
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(
              navigationShell: navigationShell,
              currentLocation: state.uri.path,
            );
          },
          branches: [
            // Money branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/money',
                  name: 'Coins',
                  builder: (context, state) => const CoinsDashboardScreen(),
                  routes: [
                    GoRoute(
                      path: 'split',
                      name: 'bill_split',
                      builder: (context, state) => const BillSplitScreen(),
                    ),
                    // Coins Feature Routes
                    GoRoute(
                      path: 'dashboard',
                      name: RouteNames.coinsDashboard,
                      builder: (context, state) => const CoinsDashboardScreen(),
                    ),
                    GoRoute(
                      path: 'add-expense',
                      name: RouteNames.coinsAddExpense,
                      builder: (context, state) => const AddExpenseScreen(),
                    ),
                    GoRoute(
                      path: 'budgets',
                      name: RouteNames.coinsBudgets,
                      builder: (context, state) =>
                          const BudgetManagementScreen(),
                    ),
                    ...coinVaultRoutes,
                    GoRoute(
                      path: 'groups',
                      name: RouteNames.coinsGroups,
                      builder: (context, state) => const GroupsListScreen(),
                      routes: [
                        GoRoute(
                          path: ':groupId',
                          name: RouteNames.coinsGroupDetail,
                          builder: (context, state) {
                            final groupId = state.pathParameters['groupId']!;
                            return GroupDetailScreen(groupId: groupId);
                          },
                          routes: [
                            GoRoute(
                              path: 'add-split',
                              name: RouteNames.coinsAddSplit,
                              builder: (context, state) {
                                final groupId =
                                    state.pathParameters['groupId']!;
                                return AddSplitExpenseScreen(groupId: groupId);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            // Mind branch. Falls back to a redirect-only route when the
            // module is absent (web) -- the branch itself stays present so
            // `navigationShell.currentIndex` keeps lining up with
            // `AppNavigationTab.values` (see navigation_provider.dart), and
            // a stray `/mind` link resolves to something instead of a 404.
            StatefulShellBranch(
              routes: assistant != null
                  ? assistant.hubRoutesFor(moduleRegistry.shell)
                  : _mindAbsentHubRoutes(),
            ),
            // Beats branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/music',
                  name: 'Beats',
                  builder: (context, state) => const MusicScreen(),
                ),
              ],
            ),
            // Stream branch
            StatefulShellBranch(routes: iptvRoutes),
            // Games branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/games',
                  name: 'Arena',
                  builder: (context, state) => const GamesHubScreen(),
                ),
              ],
            ),
            // Quest branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/quest',
                  name: 'Quest',
                  builder: (context, state) => const QuestListScreen(),
                  routes: [
                    GoRoute(
                      path: 'new',
                      name: 'quest_new',
                      builder: (context, state) => const QuestUploadScreen(),
                    ),
                    GoRoute(
                      path: ':questId',
                      name: 'quest_detail',
                      builder: (context, state) {
                        final questId = state.pathParameters['questId']!;
                        return QuestChatScreen(questId: questId);
                      },
                    ),
                  ],
                ),
              ],
            ),
            // Airo Living Console home. Live remains available at /iptv.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  name: 'Home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
      errorBuilder: (context, state) => HttpDogErrorScreen(
        statusCode: 404,
        customMessage: 'Page not found: ${state.matchedLocation}',
        onRetry: () => context.go('/money'),
      ),
    );
  }

  /// Resolves a registered module by id, typed, or `null` if it was never
  /// registered for this shell.
  ///
  /// Used instead of [_requiredModuleRoutes] when the router needs more from
  /// a module than one flat route bundle — currently the assistant, which
  /// mounts part of itself in a navigation branch and part at the top level.
  /// Nullable rather than throwing: composing without Mind is a legitimate
  /// shape, not a misconfiguration (R05 -- absent from shared surfaces by
  /// construction, not by choice).
  static T? _optionalModule<T extends AppModule>(
    ModuleRegistry registry,
    String moduleId,
  ) {
    return registry.registeredModules
        .whereType<T>()
        .where((candidate) => candidate.id == moduleId)
        .firstOrNull;
  }

  /// What the Mind branch renders when [MindModule] is absent (web, R05).
  ///
  /// A single redirect rather than an empty route list: `StatefulShellBranch`
  /// requires at least one route, and a bare `/mind` visited directly (a
  /// stale deep link, the legacy `/agent` and `/assistant` rewrites) should
  /// land somewhere real instead of a 404.
  static List<GoRoute> _mindAbsentHubRoutes() => [
    GoRoute(
      path: AssistantRouteNames.assistant,
      redirect: (context, state) => '/money',
    ),
  ];

  static List<GoRoute> _requiredModuleRoutes(
    ModuleRegistry registry,
    String moduleId,
  ) {
    final routes = registry
        .routesForModule(moduleId)
        .whereType<GoRoute>()
        .toList(growable: false);
    if (routes.isEmpty) {
      throw ModuleCompositionException(
        'Required module "$moduleId" has no GoRoute bundle for '
        'shell "${registry.shell.value}".',
      );
    }
    return routes;
  }
}

/// Rewrites a legacy hub prefix onto the current hub root, preserving whatever
/// follows it.
///
/// Two routes rather than one: GoRouter matches `/agent` and `/agent/...` as
/// separate patterns, so the bare root needs its own entry. The wildcard keeps
/// the remainder verbatim -- including query strings, which callers use for
/// notification payload ids.
List<GoRoute> _legacyHubRedirects(String legacyRoot) {
  return <GoRoute>[
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
}
