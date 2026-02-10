import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chess_game_screen_new.dart';
import 'blackjack_screen.dart';
import 'texas_holdem_screen.dart';
import 'game_coming_soon_screen.dart';
import '../../application/card_asset_manager.dart';
import '../../domain/models/game_info.dart';
import '../widgets/game_rules_dialog_unified.dart';
import '../../../../shared/widgets/responsive_center.dart';

/// Games hub screen - Mall-like balanced layout
class GamesHubScreen extends ConsumerWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gamesByCategory = GameRegistry.byCategory;

    // No AppBar here - global AppBar is in AppShell
    return Scaffold(
      body: ResponsiveCenter(
        maxWidth: ResponsiveBreakpoints.dashboardMaxWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome header
              Text(
                'Welcome to Arena',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Choose your game and start playing',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // Game categories in grid
              ...gamesByCategory.entries.map((entry) {
                final category = entry.key;
                final games = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category header
                    Row(
                      children: [
                        Icon(category.icon, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          category.displayName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        if (games.length > 4)
                          TextButton(
                            onPressed: () {
                              // TODO: View all in category
                            },
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Games grid - responsive
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = ResponsiveBreakpoints.getGridColumns(
                          constraints.maxWidth,
                          mobile: 2,
                          tablet: 3,
                          desktop: 4,
                        );
                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                          itemCount: games.length,
                          itemBuilder: (context, index) {
                            return _buildGameTile(context, ref, games[index]);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              }),

              // Quick stats
              Text('Your Stats', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Games Played',
                      '0',
                      Icons.sports_esports,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      context,
                      'Wins',
                      '0',
                      Icons.emoji_events,
                      Colors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameTile(BuildContext context, WidgetRef ref, GameInfo game) {
    // Use RepaintBoundary to prevent unnecessary repaints
    return RepaintBoundary(
      child: Card(
        child: InkWell(
          onTap: game.isAvailable ? () => _playGame(context, ref, game) : null,
          child: Opacity(
            opacity: game.isAvailable ? 1.0 : 0.6,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Game icon and status
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: game.isAvailable
                              ? game.difficulty.color.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          game.icon,
                          size: 28,
                          color: game.isAvailable
                              ? game.difficulty.color
                              : Colors.grey,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 18),
                        onPressed: () {
                          UnifiedGameRulesDialog.show(context, game);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Game name
                  Text(
                    game.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Game description
                  Text(
                    game.shortDescription,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),

                  // Game info
                  Row(
                    children: [
                      Icon(Icons.person, size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          game.playerCountDisplay,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Status badge
                  if (!game.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'COMING SOON',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _playGame(BuildContext context, WidgetRef ref, GameInfo game) {
    switch (game.id) {
      case 'blackjack':
        _playBlackjack(context, ref);
        break;
      case 'chess':
        _playChess(context);
        break;
      case 'texas_holdem':
        _playTexasHoldem(context, ref);
        break;
      default:
        // Show coming soon screen for games under development
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => GameComingSoonScreen(game: game),
          ),
        );
    }
  }

  void _playChess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const ChessGameScreenNew(),
      isScrollControlled: true,
      useSafeArea: true,
    );
  }

  void _playBlackjack(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CardImagePreloader(
          preloadAll: false,
          child: BlackjackScreen(),
        ),
      ),
    );
  }

  void _playTexasHoldem(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CardImagePreloader(
          preloadAll: false,
          child: TexasHoldemScreen(),
        ),
      ),
    );
  }
}
