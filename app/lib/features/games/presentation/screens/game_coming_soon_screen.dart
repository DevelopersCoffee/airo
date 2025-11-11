import 'package:flutter/material.dart';
import '../../domain/models/game_info.dart';
import '../widgets/game_rules_dialog_unified.dart';

/// Generic "Coming Soon" screen for games under development
class GameComingSoonScreen extends StatelessWidget {
  final GameInfo game;

  const GameComingSoonScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(game.name),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              UnifiedGameRulesDialog.show(context, game);
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              game.difficulty.color.withValues(alpha: 0.1),
              game.difficulty.color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Game icon
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: game.difficulty.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    game.icon,
                    size: 80,
                    color: game.difficulty.color,
                  ),
                ),
                const SizedBox(height: 32),

                // Game name
                Text(
                  game.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Description
                Text(
                  game.description,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Coming soon badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.construction,
                        color: Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Full Gameplay Coming Soon',
                        style: TextStyle(
                          color: Colors.orange[800],
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Game info
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.people,
                          'Players',
                          game.playerCountDisplay,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.speed,
                          'Difficulty',
                          game.difficulty.displayName,
                        ),
                        const Divider(),
                        _buildInfoRow(
                          Icons.category,
                          'Category',
                          game.category.displayName,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // View rules button
                ElevatedButton.icon(
                  onPressed: () {
                    UnifiedGameRulesDialog.show(context, game);
                  },
                  icon: const Icon(Icons.menu_book),
                  label: const Text('View Rules & How to Play'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    backgroundColor: game.difficulty.color,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),

                // Status message
                Text(
                  'This game is currently under development.\nCheck back soon for the full experience!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

