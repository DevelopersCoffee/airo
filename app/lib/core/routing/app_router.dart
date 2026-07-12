import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/airo_explore/presentation/screens/airo_explore_screen.dart';
import '../../features/agent_chat/presentation/screens/chat_screen.dart';
import '../../features/agent_chat/presentation/screens/model_library_screen.dart';
import '../../features/agent_chat/presentation/screens/notifications_screen.dart';
import '../../features/agent_chat/presentation/screens/profile_screen.dart';
import 'package:feature_iptv/feature_iptv.dart';
import '../../features/games/presentation/screens/games_hub_screen.dart';
import '../../features/mind/presentation/screens/mind_screen.dart';
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
import '../../core/auth/auth_service.dart';
import '../../core/app/app_shell.dart';
import '../http/http_dog.dart';
import 'route_names.dart';

class AppRouter {
  // Private constructor to prevent instantiation
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/money',
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
      GoRoute(path: '/agent', redirect: (context, state) => '/mind'),
      GoRoute(
        path: '/agent/notifications',
        redirect: (context, state) => '/mind/notifications',
      ),
      GoRoute(
        path: '/agent/profile',
        redirect: (context, state) => '/mind/profile',
      ),
      GoRoute(
        path: '/agent/models',
        redirect: (context, state) => '/mind/models',
      ),
      GoRoute(path: '/beats', redirect: (context, state) => '/music'),
      GoRoute(path: '/stream', redirect: (context, state) => '/iptv'),
      GoRoute(path: '/live', redirect: (context, state) => '/music'),
      GoRoute(path: '/live/music', redirect: (context, state) => '/music'),
      GoRoute(path: '/live/tv', redirect: (context, state) => '/iptv'),
      GoRoute(
        path: '/airo-explore',
        name: 'airo_explore',
        builder: (context, state) => const AiroExploreScreen(),
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
                    builder: (context, state) => const BudgetManagementScreen(),
                  ),
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
                              final groupId = state.pathParameters['groupId']!;
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
                path: '/mind',
                name: 'Mind',
                builder: (context, state) => const MindScreen(),
                routes: [
                  GoRoute(
                    path: 'chat',
                    name: 'mind_chat',
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
                        context.go('/mind');
                      },
                      onOpenModelManager: () {
                        context.push('/mind/profile');
                      },
                    ),
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
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/iptv',
                name: 'Stream',
                builder: (context, state) => const IPTVScreen(),
              ),
            ],
          ),
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
