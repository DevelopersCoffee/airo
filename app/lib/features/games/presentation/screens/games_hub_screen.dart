import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'chess_game_screen_new.dart';

/// Games hub screen
class GamesHubScreen extends ConsumerWidget {
  const GamesHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arena'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              // TODO: Show leaderboard
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Featured game - Chess
            Card(
              child: InkWell(
                onTap: () => _playChess(context),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.brown.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.games,
                          size: 64,
                          color: Colors.brown[700],
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Chess Master',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Play chess with AI opponent. Featuring voice lines, reactive music, and competitive banter.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => _playChess(context),
                        child: const Text('Play Now'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // All games section
            Text('All Games', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: 1,
              itemBuilder: (context, index) {
                return Card(
                  child: InkWell(
                    onTap: () => _playChess(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.games, size: 48, color: Colors.brown[700]),
                        const SizedBox(height: 8),
                        const Text(
                          'Chess Master',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'vs AI',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Achievements section
            Text('Achievements', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: const ListTile(
                  title: Text('No achievements yet'),
                  subtitle: Text('Play games to unlock achievements'),
                  leading: Icon(Icons.emoji_events),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _playChess(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const ChessGameScreenNew(),
      isScrollControlled: true,
      useSafeArea: true,
    );
  }
}
