import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/texas_holdem_notifier.dart';
import '../../domain/models/texas_holdem_model.dart';
import '../widgets/playing_card_widget.dart';

/// Texas Hold'em poker screen
class TexasHoldemScreen extends ConsumerStatefulWidget {
  const TexasHoldemScreen({super.key});

  @override
  ConsumerState<TexasHoldemScreen> createState() => _TexasHoldemScreenState();
}

class _TexasHoldemScreenState extends ConsumerState<TexasHoldemScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(texasHoldemGameProvider.notifier).startNewGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(texasHoldemGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Texas Hold\'em'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(texasHoldemGameProvider.notifier).startNewGame();
            },
          ),
        ],
      ),
      body: game == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.green[900]!, Colors.green[700]!],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Pot and phase info
                    _buildGameInfo(game),

                    // Community cards
                    _buildCommunityCards(game),

                    const Spacer(),

                    // AI players
                    _buildAIPlayers(game),

                    const Spacer(),

                    // Player's hand
                    _buildPlayerHand(game),

                    // Controls
                    _buildControls(game),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildGameInfo(TexasHoldemGame game) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoChip('Pot', '\$${game.pot}', Colors.amber),
              _buildInfoChip('Bet', '\$${game.currentBet}', Colors.blue),
              _buildInfoChip(
                'Phase',
                game.phase.name.toUpperCase(),
                Colors.purple,
              ),
            ],
          ),
          if (game.message != null) ...[
            const SizedBox(height: 8),
            Text(
              game.message!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityCards(TexasHoldemGame game) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: game.communityCards.isEmpty
          ? const Center(
              child: Text(
                'Community Cards',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: game.communityCards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: PlayingCardWidget(card: card),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _buildAIPlayers(TexasHoldemGame game) {
    final aiPlayers = game.players.skip(1).toList();

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: aiPlayers.length,
        itemBuilder: (context, index) {
          final player = aiPlayers[index];
          final isCurrentPlayer =
              game.players.indexOf(player) == game.currentPlayerIndex;

          return Container(
            width: 120,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCurrentPlayer
                  ? Colors.yellow.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentPlayer ? Colors.yellow : Colors.white30,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${player.chips}',
                  style: const TextStyle(color: Colors.amber, fontSize: 12),
                ),
                if (player.isFolded)
                  const Text(
                    'FOLDED',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (player.currentBet > 0)
                  Text(
                    'Bet: \$${player.currentBet}',
                    style: const TextStyle(color: Colors.white70, fontSize: 10),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayerHand(TexasHoldemGame game) {
    final player = game.players[0];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Your Hand - \$${player.chips}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: player.holeCards
                  .map(
                    (card) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: PlayingCardWidget(card: card),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(TexasHoldemGame game) {
    if (game.phase == TexasHoldemPhase.gameOver) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              game.winner != null ? '${game.winner} wins!' : 'Game Over',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                ref.read(texasHoldemGameProvider.notifier).startNewGame();
              },
              child: const Text('New Game'),
            ),
          ],
        ),
      );
    }

    if (!game.isPlayerTurn) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'Waiting for other players...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: () {
              ref.read(texasHoldemGameProvider.notifier).fold();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Fold'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(texasHoldemGameProvider.notifier).call();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Call'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(texasHoldemGameProvider.notifier).raise(game.bigBlind);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Raise'),
          ),
        ],
      ),
    );
  }
}
