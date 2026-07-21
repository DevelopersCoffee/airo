import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/bill_split/presentation/screens/bill_split_screen.dart';
import '../../features/airo_explore/presentation/screens/airo_explore_screen.dart';
import '../../features/agent_chat/presentation/screens/chat_screen.dart';
import '../../features/agent_chat/presentation/screens/model_library_screen.dart';
import '../../features/agent_chat/presentation/screens/notifications_screen.dart';
import '../../features/agent_chat/presentation/screens/profile_screen.dart';
import '../../features/settings/presentation/screens/settings_hub_screen.dart';
import 'package:feature_iptv/feature_iptv.dart';
import '../../features/iptv/phone_media_local_picker.dart';
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
import '../../features/life_track/presentation/screens/track_detail_screen.dart';
import '../../features/life_track/presentation/screens/track_list_screen.dart';
import '../../core/auth/auth_service.dart';
import '../../core/app/app_shell.dart';
import '../http/http_dog.dart';
import 'route_names.dart';

class AppRouter {
  // Private constructor to prevent instantiation
  AppRouter._();

  static final GoRouter router = createRouter();

  static GoRouter createRouter({String initialLocation = '/money'}) {
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
        // Settings moved into the StatefulShellRoute below (CV unified-browse
        // Task 5) so it's a persistent bottom-nav tab, matching the TV
        // sidebar's Settings destination, instead of a one-off pushed route.
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
                  builder: (context, state) => IPTVScreen(
                    onOpenVod: () => context.go('/vod'),
                    onPickLocalMediaForTv: kDebugMode
                        ? pickPhoneLocalMediaForTv
                        : null,
                    deepLinkChannelId: state.uri.queryParameters['channel'],
                  ),
                ),
                GoRoute(
                  path: '/vod',
                  name: 'VOD',
                  builder: (context, state) => const VodScreen(),
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
            // Home branch (CV unified-browse Task 6): the source design's
            // sidebar has Home and Live TV both call the same `goToBrowse`
            // handler — Home and Live are the same destination — so this
            // mirrors the Stream branch's IPTVScreen wiring exactly rather
            // than the Task 5 MindScreen placeholder. Matches
            // AppNavigationTab.home — see task-6-report.md for the decision.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  name: 'Home',
                  builder: (context, state) => IPTVScreen(
                    onOpenVod: () => context.go('/vod'),
                    onPickLocalMediaForTv: kDebugMode
                        ? pickPhoneLocalMediaForTv
                        : null,
                  ),
                ),
              ],
            ),
            // Guide branch (CV unified-browse Task 5): reuses the existing
            // IptvGuideScreen (previously only reachable via an in-screen
            // Navigator.push from IPTVScreen) as its own persistent tab.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/guide',
                  name: 'Guide',
                  builder: (context, state) => IptvGuideScreen(
                    onChannelSelected: () => context.go('/iptv'),
                  ),
                ),
              ],
            ),
            // Favorites branch (CV unified-browse Task 5): uses the real
            // mobile favorites screen (packages/feature_iptv/lib/presentation/
            // screens/mobile_favorites_screen.dart), landed on main after this
            // task's original TvFavoritesScreen stopgap — picked up on rebase.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/favorites',
                  name: 'Favorites',
                  builder: (context, state) => MobileFavoritesScreen(
                    onChannelSelected: () => context.go('/iptv'),
                  ),
                ),
              ],
            ),
            // Settings branch (CV unified-browse Task 5): moved from a
            // standalone pushed route (above) into the shell so it behaves as
            // a persistent tab, matching the TV sidebar's Settings destination.
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: RouteNames.settings,
                  name: RouteNames.settings,
                  builder: (context, state) => const SettingsHubScreen(),
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
}
