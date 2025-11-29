import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/money/presentation/screens/money_overview_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/agent_chat/presentation/screens/chat_screen.dart';
import '../../features/agent_chat/presentation/screens/profile_screen.dart';
import '../../features/music/presentation/screens/music_screen.dart';
import '../../features/games/presentation/screens/games_hub_screen.dart';
import '../../features/offers/presentation/screens/offers_feed_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/quest/presentation/screens/quest_list_screen.dart';
import '../../features/quest/presentation/screens/quest_upload_screen.dart';
import '../../features/quest/presentation/screens/quest_chat_screen.dart';
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
          // Music branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/music',
                name: 'Beats',
                builder: (context, state) => const MusicScreen(),
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
          // Offers branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/offers',
                name: 'Loot',
                builder: (context, state) => const OffersFeedScreen(),
              ),
            ],
          ),
          // Reader branch
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reader',
                name: 'Tales',
                builder: (context, state) => const ReaderScreen(),
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
                    name: 'quest_chat',
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
      onRetry: () => context.go('/agent'),
    ),
  );
}
