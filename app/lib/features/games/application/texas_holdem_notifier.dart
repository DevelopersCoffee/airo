import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/texas_holdem_model.dart';
import '../domain/models/card_model.dart';
import '../domain/services/deck_of_cards_service.dart';
import 'blackjack_notifier.dart';

/// Provider for Texas Hold'em game state
final texasHoldemGameProvider =
    StateNotifierProvider<TexasHoldemNotifier, TexasHoldemGame?>((ref) {
      return TexasHoldemNotifier(ref.read(deckOfCardsServiceProvider));
    });

/// Texas Hold'em game state manager
class TexasHoldemNotifier extends StateNotifier<TexasHoldemGame?> {
  final DeckOfCardsService _deckService;

  TexasHoldemNotifier(this._deckService) : super(null);

  /// Start a new game with specified number of AI players
  Future<void> startNewGame({int aiPlayers = 3}) async {
    try {
      // Shuffle new deck
      final deckResponse = await _deckService.createShuffledDeck(deckCount: 1);

      // Create players (player + AI)
      final players = <TexasHoldemPlayer>[
        TexasHoldemPlayer(
          id: 'player',
          name: 'You',
          chips: 1000,
          holeCards: [],
          isDealer: true,
        ),
      ];

      for (int i = 0; i < aiPlayers; i++) {
        players.add(
          TexasHoldemPlayer(
            id: 'ai_$i',
            name: 'AI ${i + 1}',
            chips: 1000,
            holeCards: [],
          ),
        );
      }

      // Initialize game state
      state = TexasHoldemGame(
        deckId: deckResponse.deckId,
        players: players,
        communityCards: [],
        pot: 0,
        phase: TexasHoldemPhase.preflop,
        currentBet: 0,
        smallBlind: 10,
        bigBlind: 20,
        currentPlayerIndex: 0,
        dealerIndex: 0,
        message: 'New game started! Post blinds to begin.',
      );

      // Deal hole cards
      await _dealHoleCards();
    } catch (e) {
      state = state?.copyWith(message: 'Error starting game: $e');
    }
  }

  /// Deal 2 hole cards to each player
  Future<void> _dealHoleCards() async {
    if (state == null) return;

    try {
      // Draw 2 cards per player
      final cardCount = state!.players.length * 2;
      final drawResponse = await _deckService.drawCards(
        deckId: state!.deckId,
        count: cardCount,
      );

      // Distribute cards
      final updatedPlayers = <TexasHoldemPlayer>[];
      int cardIndex = 0;

      for (final player in state!.players) {
        final holeCards = <CardModel>[
          drawResponse.cards[cardIndex],
          drawResponse.cards[cardIndex + 1],
        ];
        cardIndex += 2;

        updatedPlayers.add(player.copyWith(holeCards: holeCards));
      }

      state = state!.copyWith(
        players: updatedPlayers,
        message: 'Cards dealt. Place your bets!',
      );

      // Post blinds
      await _postBlinds();
    } catch (e) {
      state = state?.copyWith(message: 'Error dealing cards: $e');
    }
  }

  /// Post small and big blinds
  Future<void> _postBlinds() async {
    if (state == null) return;

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);

    // Small blind (next to dealer)
    final sbIndex = (state!.dealerIndex + 1) % updatedPlayers.length;
    updatedPlayers[sbIndex] = updatedPlayers[sbIndex].copyWith(
      currentBet: state!.smallBlind,
      chips: updatedPlayers[sbIndex].chips - state!.smallBlind,
      isSmallBlind: true,
    );

    // Big blind (next to small blind)
    final bbIndex = (state!.dealerIndex + 2) % updatedPlayers.length;
    updatedPlayers[bbIndex] = updatedPlayers[bbIndex].copyWith(
      currentBet: state!.bigBlind,
      chips: updatedPlayers[bbIndex].chips - state!.bigBlind,
      isBigBlind: true,
    );

    state = state!.copyWith(
      players: updatedPlayers,
      pot: state!.smallBlind + state!.bigBlind,
      currentBet: state!.bigBlind,
      currentPlayerIndex: (bbIndex + 1) % updatedPlayers.length,
      message: 'Blinds posted. Your turn!',
    );
  }

  /// Player folds
  Future<void> fold() async {
    if (state == null || !state!.isPlayerTurn) return;

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
    updatedPlayers[0] = updatedPlayers[0].copyWith(isFolded: true);

    state = state!.copyWith(players: updatedPlayers, message: 'You folded.');

    await _nextPlayer();
  }

  /// Player calls current bet
  Future<void> call() async {
    if (state == null || !state!.isPlayerTurn) return;

    final player = state!.players[0];
    final callAmount = state!.currentBet - player.currentBet;

    if (callAmount > player.chips) {
      // All-in
      await allIn();
      return;
    }

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
    updatedPlayers[0] = player.copyWith(
      currentBet: state!.currentBet,
      chips: player.chips - callAmount,
    );

    state = state!.copyWith(
      players: updatedPlayers,
      pot: state!.pot + callAmount,
      message: 'You called \$$callAmount',
    );

    await _nextPlayer();
  }

  /// Player raises bet
  Future<void> raise(int amount) async {
    if (state == null || !state!.isPlayerTurn) return;

    final player = state!.players[0];
    final totalBet = state!.currentBet + amount;

    if (totalBet > player.chips + player.currentBet) {
      state = state!.copyWith(message: 'Not enough chips!');
      return;
    }

    final raiseAmount = totalBet - player.currentBet;

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
    updatedPlayers[0] = player.copyWith(
      currentBet: totalBet,
      chips: player.chips - raiseAmount,
    );

    state = state!.copyWith(
      players: updatedPlayers,
      pot: state!.pot + raiseAmount,
      currentBet: totalBet,
      message: 'You raised to \$$totalBet',
    );

    await _nextPlayer();
  }

  /// Player goes all-in
  Future<void> allIn() async {
    if (state == null || !state!.isPlayerTurn) return;

    final player = state!.players[0];
    final allInAmount = player.chips;

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
    updatedPlayers[0] = player.copyWith(
      currentBet: player.currentBet + allInAmount,
      chips: 0,
      isAllIn: true,
    );

    state = state!.copyWith(
      players: updatedPlayers,
      pot: state!.pot + allInAmount,
      message: 'You went all-in with \$$allInAmount!',
    );

    await _nextPlayer();
  }

  /// Move to next player or next phase
  Future<void> _nextPlayer() async {
    if (state == null) return;

    // Check if only one player left
    final activePlayers = state!.players.where((p) => !p.isFolded).toList();
    if (activePlayers.length == 1) {
      await _endGame(winner: activePlayers.first);
      return;
    }

    // Find next active player
    int nextIndex = (state!.currentPlayerIndex + 1) % state!.players.length;
    while (state!.players[nextIndex].isFolded ||
        state!.players[nextIndex].isAllIn) {
      nextIndex = (nextIndex + 1) % state!.players.length;

      // If we've gone full circle, move to next phase
      if (nextIndex == state!.currentPlayerIndex) {
        await _nextPhase();
        return;
      }
    }

    state = state!.copyWith(currentPlayerIndex: nextIndex);

    // AI turn
    if (nextIndex != 0) {
      await Future.delayed(const Duration(milliseconds: 1000));
      await _aiTurn();
    }
  }

  /// AI player makes a decision
  Future<void> _aiTurn() async {
    if (state == null) return;

    final aiPlayer = state!.currentPlayer;

    // Simple AI logic: 70% call, 20% fold, 10% raise
    final random = DateTime.now().millisecondsSinceEpoch % 100;

    if (random < 20) {
      // Fold
      final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
      updatedPlayers[state!.currentPlayerIndex] = aiPlayer.copyWith(
        isFolded: true,
      );
      state = state!.copyWith(
        players: updatedPlayers,
        message: '${aiPlayer.name} folded',
      );
    } else if (random < 90) {
      // Call
      final callAmount = state!.currentBet - aiPlayer.currentBet;
      final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
      updatedPlayers[state!.currentPlayerIndex] = aiPlayer.copyWith(
        currentBet: state!.currentBet,
        chips: aiPlayer.chips - callAmount,
      );
      state = state!.copyWith(
        players: updatedPlayers,
        pot: state!.pot + callAmount,
        message: '${aiPlayer.name} called \$$callAmount',
      );
    } else {
      // Raise
      final raiseAmount = state!.bigBlind;
      final totalBet = state!.currentBet + raiseAmount;
      final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
      updatedPlayers[state!.currentPlayerIndex] = aiPlayer.copyWith(
        currentBet: totalBet,
        chips: aiPlayer.chips - (totalBet - aiPlayer.currentBet),
      );
      state = state!.copyWith(
        players: updatedPlayers,
        pot: state!.pot + (totalBet - aiPlayer.currentBet),
        currentBet: totalBet,
        message: '${aiPlayer.name} raised to \$$totalBet',
      );
    }

    await _nextPlayer();
  }

  /// Move to next phase (flop, turn, river, showdown)
  Future<void> _nextPhase() async {
    // Implementation continues...
    // For now, simplified version
    state = state!.copyWith(message: 'Round complete! (Simplified version)');
  }

  /// End game and determine winner
  Future<void> _endGame({required TexasHoldemPlayer winner}) async {
    if (state == null) return;

    final updatedPlayers = List<TexasHoldemPlayer>.from(state!.players);
    final winnerIndex = updatedPlayers.indexWhere((p) => p.id == winner.id);
    updatedPlayers[winnerIndex] = updatedPlayers[winnerIndex].copyWith(
      chips: updatedPlayers[winnerIndex].chips + state!.pot,
    );

    state = state!.copyWith(
      players: updatedPlayers,
      phase: TexasHoldemPhase.gameOver,
      winner: winner.name,
      message: '${winner.name} wins \$${state!.pot}!',
      pot: 0,
    );
  }
}
