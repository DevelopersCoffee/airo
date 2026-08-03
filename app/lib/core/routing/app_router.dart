import 'package:core_product_shell/core_product_shell.dart';
import 'package:core_ai/core_ai.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/airo_explore/presentation/screens/airo_explore_screen.dart';
import '../../features/agent_chat/presentation/screens/chat_screen.dart';
import '../../features/agent_chat/presentation/screens/model_library_screen.dart';
import '../../features/agent_chat/presentation/screens/device_capability_report_screen.dart';
import '../../features/agent_chat/presentation/screens/model_advisor_screen.dart';
import '../../features/agent_chat/presentation/screens/agent_skills_screen.dart';
import '../../features/agent_chat/presentation/screens/notifications_screen.dart';
import '../../features/agent_chat/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import '../../features/settings/presentation/screens/airo_portability_screen.dart';
import '../../features/games/presentation/screens/games_hub_screen.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/wellbeing/presentation/screens/wellbeing_screen.dart';
import '../../features/assistant/presentation/screens/prompt_lab_screen.dart';
import '../../features/assistant/presentation/screens/audio_scribe_screen.dart';
import '../../features/assistant/presentation/screens/mobile_actions_screen.dart';
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
        // Wellbeing split off the old Mind hub in milestone 22. It is a
        // destination rather than a tab: three cards and a streak do not earn
        // a slot in the bottom nav, and the assistant hub links to it.
        GoRoute(
          path: '/wellbeing',
          name: 'Wellbeing',
          builder: (context, state) => const WellbeingScreen(),
        ),
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
              routes: [
                GoRoute(
                  path: '/assistant',
                  name: 'Assistant',
                  builder: (context, state) => const AssistantScreen(),
                  routes: [
                    GoRoute(
                      path: 'chat',
                      name: 'assistant_chat',
                      builder: (context, state) => ChatScreen(
                        initialDraft: state.uri.queryParameters['prefill'],
                      ),
                    ),
                    GoRoute(
                      path: 'notifications',
                      name: 'agent_notifications',
                      builder: (context, state) => NotificationsScreen(
                        initialCategory: state.uri.queryParameters['category'],
                      ),
                    ),
                    GoRoute(
                      path: 'profile',
                      name: 'profile',
                      builder: (context, state) => const ProfileScreen(),
                    ),
                    GoRoute(
                      path: 'models',
                      name: 'assistant_models',
                      builder: (context, state) => ModelLibraryScreen(
                        onModelSelected: (candidate) {
                          context.go('/assistant');
                        },
                        onOpenModelManager: () {
                          context.push('/assistant/profile');
                        },
                      ),
                    ),
                    GoRoute(
                      path: 'device-capabilities',
                      name: 'assistant_device_capabilities',
                      builder: (context, state) =>
                          DeviceCapabilityReportLoaderScreen(
                            models: ModelCatalog.bundledModels,
                          ),
                    ),
                    GoRoute(
                      path: 'model-advisor',
                      name: 'assistant_model_advisor',
                      builder: (context, state) => const ModelAdvisorScreen(),
                    ),
                    GoRoute(
                      path: 'prompt-lab',
                      name: 'assistant_prompt_lab',
                      builder: (context, state) => PromptLabScreen(
                        initialImageMode:
                            state.uri.queryParameters['mode'] == 'image',
                      ),
                    ),
                    GoRoute(
                      path: 'audio-scribe',
                      name: 'assistant_audio_scribe',
                      builder: (context, state) => const AudioScribeScreen(),
                    ),
                    GoRoute(
                      path: 'skills',
                      name: 'assistant_agent_skills',
                      builder: (context, state) => const AgentSkillsScreen(),
                    ),
                    GoRoute(
                      path: 'mobile-actions',
                      name: 'assistant_mobile_actions',
                      builder: (context, state) => const MobileActionsScreen(),
                    ),
                  ],
                ),
              ],
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
