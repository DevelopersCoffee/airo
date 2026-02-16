import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/money/presentation/screens/money_overview_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/agent_chat/presentation/screens/chat_screen.dart';
import '../../features/agent_chat/presentation/screens/profile_screen.dart';
import '../../features/live/presentation/screens/live_screen.dart';
import '../../features/games/presentation/screens/games_hub_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
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
    initialLocation: '/agent',
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

      // If logged in and on login page, redirect to agent tab
      if (isLoggedIn && isLoginRoute) {
        return '/agent';
      }

      return null; // No redirect needed
    },
    routes: [
      // Redirect root to agent
      GoRoute(path: '/', redirect: (context, state) => '/agent'),
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
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Money branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/money',
                name: 'Coins',
                builder: (context, state) => const MoneyOverviewScreen(),
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
          // Agent Chat branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/agent',
                name: 'Mind',
                builder: (context, state) => const ChatScreen(),
                routes: [
                  GoRoute(
                    path: 'profile',
                    name: 'profile',
                    builder: (context, state) => const ProfileScreen(),
                  ),
                ],
              ),
            ],
          ),
          // Live branch (Music + IPTV/Stream unified with toggle)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/live',
                name: 'Live',
                builder: (context, state) => const LiveScreen(),
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
          // Tales branch (Reader/Manga)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/tales',
                name: 'Tales',
                builder: (context, state) => const ReaderScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => HttpDogErrorScreen(
      statusCode: 404,
      customMessage: 'Page not found: ${state.matchedLocation}',
      onRetry: () => context.go('/agent'),
    ),
  );
}
