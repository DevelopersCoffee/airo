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
    final assistant = _requiredModule<MindModule>(moduleRegistry, 'mind');

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
        GoRoute(path: '/agent', redirect: (context, state) => '/assistant'),
        GoRoute(
          path: '/agent/notifications',
          redirect: (context, state) => '/assistant/notifications',
        ),
        GoRoute(
          path: '/agent/profile',
          redirect: (context, state) => '/assistant/profile',
        ),
        GoRoute(
          path: '/agent/models',
          redirect: (context, state) => '/assistant/models',
        ),
        // Assistant destinations that are reached from the Mind hub but are
        // not part of it (Wellbeing), so they render full-screen instead of
        // inside the bottom nav.
        ...assistant.rootRoutesFor(moduleRegistry.shell),
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
            // Mind branch
            StatefulShellBranch(
              routes: assistant.hubRoutesFor(moduleRegistry.shell),
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

  /// Resolves a registered module the shell cannot start without, typed.
  ///
  /// Used instead of [_requiredModuleRoutes] when the router needs more from a
  /// module than one flat route bundle — currently the assistant, which mounts
  /// part of itself in a navigation branch and part at the top level.
  static T _requiredModule<T extends AppModule>(
    ModuleRegistry registry,
    String moduleId,
  ) {
    final module = registry.registeredModules
        .whereType<T>()
        .where((candidate) => candidate.id == moduleId)
        .firstOrNull;
    if (module == null) {
      throw ModuleCompositionException(
        'Required module "$moduleId" is not registered as a $T for '
        'shell "${registry.shell.value}".',
      );
    }
    return module;
  }

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
