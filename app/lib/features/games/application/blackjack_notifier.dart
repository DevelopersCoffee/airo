import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/blackjack_model.dart';
import '../domain/models/card_model.dart';
import '../domain/services/deck_of_cards_service.dart';

/// Provider for Blackjack game settings
final blackjackSettingsProvider = StateProvider<BlackjackSettings>((ref) {
  return const BlackjackSettings();
});

/// Provider for Deck of Cards service
final deckOfCardsServiceProvider = Provider<DeckOfCardsService>((ref) {
  return DeckOfCardsService();
});

/// Provider for Blackjack game state
final blackjackGameProvider =
    StateNotifierProvider<BlackjackNotifier, BlackjackGame?>((ref) {
      final service = ref.watch(deckOfCardsServiceProvider);
      final settings = ref.watch(blackjackSettingsProvider);
      return BlackjackNotifier(service, settings);
    });

/// Blackjack game state notifier
class BlackjackNotifier extends StateNotifier<BlackjackGame?> {
  final DeckOfCardsService _service;
  final BlackjackSettings _settings;

  BlackjackNotifier(this._service, this._settings) : super(null);

  /// Start a new game
  Future<void> startNewGame() async {
    try {
      // Create and shuffle deck
      final deckResponse = await _service.createShuffledDeck(
        deckCount: _settings.deckCount,
      );

      state = BlackjackGame(
        deckId: deckResponse.deckId,
        playerHand: [],
        dealerHand: [],
        playerBalance: _settings.startingBalance,
        currentBet: 0,
        status: BlackjackGameStatus.betting,
        remainingCards: deckResponse.remaining,
      );
    } catch (e) {
      // Handle error
      state = null;
    }
  }

  /// Place a bet and deal initial cards
  Future<void> placeBet(int amount) async {
    if (state == null) return;
    if (amount < _settings.minimumBet || amount > _settings.maximumBet) return;
    if (amount > state!.playerBalance) return;

    try {
      // Draw 4 cards (2 for player, 2 for dealer)
      final drawResponse = await _service.drawCards(
        deckId: state!.deckId,
        count: 4,
      );

      final cards = drawResponse.cards;
      final playerHand = [cards[0], cards[2]];
      final dealerHand = [cards[1], cards[3]];

      final playerValue = BlackjackHandCalculator.calculateHandValue(
        playerHand,
      );
      final isPlayerBlackjack = BlackjackHandCalculator.isBlackjack(playerHand);

      state = state!.copyWith(
        playerHand: playerHand,
        dealerHand: dealerHand,
        currentBet: amount,
        playerBalance: state!.playerBalance - amount,
        remainingCards: drawResponse.remaining,
        dealerCardHidden: true,
        status: isPlayerBlackjack
            ? BlackjackGameStatus.blackjack
            : BlackjackGameStatus.playing,
        canHit: !isPlayerBlackjack,
        canStand: !isPlayerBlackjack,
        canDouble: !isPlayerBlackjack && state!.playerBalance >= amount,
        canSplit:
            !isPlayerBlackjack &&
            BlackjackHandCalculator.canSplit(playerHand) &&
            state!.playerBalance >= amount,
        message: isPlayerBlackjack ? 'Blackjack! You win!' : null,
      );

      // If player has blackjack, resolve immediately
      if (isPlayerBlackjack) {
        await _resolveBlackjack();
      }
    } catch (e) {
      // Handle error
    }
  }

  /// Player hits (draws a card)
  Future<void> hit() async {
    if (state == null || !state!.canHit) return;

    try {
      final drawResponse = await _service.drawCards(
        deckId: state!.deckId,
        count: 1,
      );

      final newHand = [...state!.playerHand, ...drawResponse.cards];
      final handValue = BlackjackHandCalculator.calculateHandValue(newHand);
      final isBust = handValue > 21;

      state = state!.copyWith(
        playerHand: newHand,
        remainingCards: drawResponse.remaining,
        canHit: !isBust,
        canStand: !isBust,
        canDouble: false,
        canSplit: false,
        status: isBust ? BlackjackGameStatus.bust : BlackjackGameStatus.playing,
        message: isBust ? 'Bust! You lose.' : null,
      );

      // If player busts, end game
      if (isBust) {
        await Future.delayed(const Duration(seconds: 2));
        await _resetForNextRound();
      }
    } catch (e) {
      // Handle error
    }
  }

  /// Player stands (ends their turn)
  Future<void> stand() async {
    if (state == null || !state!.canStand) return;

    state = state!.copyWith(
      canHit: false,
      canStand: false,
      canDouble: false,
      canSplit: false,
      dealerCardHidden: false,
      status: BlackjackGameStatus.dealerTurn,
    );

    // Dealer plays
    await _dealerPlay();
  }

  /// Player doubles down (doubles bet and draws one card)
  Future<void> doubleDown() async {
    if (state == null || !state!.canDouble) return;

    try {
      final drawResponse = await _service.drawCards(
        deckId: state!.deckId,
        count: 1,
      );

      final newHand = [...state!.playerHand, ...drawResponse.cards];
      final handValue = BlackjackHandCalculator.calculateHandValue(newHand);
      final isBust = handValue > 21;

      state = state!.copyWith(
        playerHand: newHand,
        currentBet: state!.currentBet * 2,
        playerBalance: state!.playerBalance - state!.currentBet,
        remainingCards: drawResponse.remaining,
        canHit: false,
        canStand: false,
        canDouble: false,
        canSplit: false,
        dealerCardHidden: false,
        status: isBust
            ? BlackjackGameStatus.bust
            : BlackjackGameStatus.dealerTurn,
        message: isBust ? 'Bust! You lose.' : null,
      );

      if (isBust) {
        await Future.delayed(const Duration(seconds: 2));
        await _resetForNextRound();
      } else {
        // Dealer plays
        await _dealerPlay();
      }
    } catch (e) {
      // Handle error
    }
  }

  /// Dealer plays according to rules
  Future<void> _dealerPlay() async {
    if (state == null) return;

    await Future.delayed(const Duration(milliseconds: 500));

    var dealerHand = state!.dealerHand;
    var dealerValue = BlackjackHandCalculator.calculateHandValue(dealerHand);

    // Dealer hits until 17 or higher
    while (dealerValue < 17 ||
        (_settings.dealerHitsSoft17 &&
            dealerValue == 17 &&
            BlackjackHandCalculator.isSoft(dealerHand))) {
      await Future.delayed(const Duration(milliseconds: 800));

      final drawResponse = await _service.drawCards(
        deckId: state!.deckId,
        count: 1,
      );

      dealerHand = [...dealerHand, ...drawResponse.cards];
      dealerValue = BlackjackHandCalculator.calculateHandValue(dealerHand);

      state = state!.copyWith(
        dealerHand: dealerHand,
        remainingCards: drawResponse.remaining,
      );
    }

    // Determine winner
    await _determineWinner();
  }

  /// Determine the winner and update balance
  Future<void> _determineWinner() async {
    if (state == null) return;

    final playerValue = BlackjackHandCalculator.calculateHandValue(
      state!.playerHand,
    );
    final dealerValue = BlackjackHandCalculator.calculateHandValue(
      state!.dealerHand,
    );
    final dealerBust = dealerValue > 21;

    BlackjackGameStatus status;
    String message;
    int winnings = 0;

    if (dealerBust) {
      status = BlackjackGameStatus.playerWin;
      message = 'Dealer busts! You win!';
      winnings = state!.currentBet * 2;
    } else if (playerValue > dealerValue) {
      status = BlackjackGameStatus.playerWin;
      message = 'You win!';
      winnings = state!.currentBet * 2;
    } else if (playerValue < dealerValue) {
      status = BlackjackGameStatus.dealerWin;
      message = 'Dealer wins.';
      winnings = 0;
    } else {
      status = BlackjackGameStatus.push;
      message = 'Push! Bet returned.';
      winnings = state!.currentBet;
    }

    state = state!.copyWith(
      status: status,
      message: message,
      playerBalance: state!.playerBalance + winnings,
    );

    await Future.delayed(const Duration(seconds: 3));
    await _resetForNextRound();
  }

  /// Handle blackjack payout
  Future<void> _resolveBlackjack() async {
    if (state == null) return;

    final payout = (state!.currentBet * _settings.blackjackPayout.multiplier)
        .round();
    final winnings = state!.currentBet + payout;

    state = state!.copyWith(playerBalance: state!.playerBalance + winnings);

    await Future.delayed(const Duration(seconds: 3));
    await _resetForNextRound();
  }

  /// Reset for next round
  Future<void> _resetForNextRound() async {
    if (state == null) return;

    // Check if we need to reshuffle (less than 25% remaining)
    if (state!.remainingCards < (52 * _settings.deckCount * 0.25)) {
      final deckResponse = await _service.reshuffleDeck(deckId: state!.deckId);

      state = state!.copyWith(remainingCards: deckResponse.remaining);
    }

    state = state!.copyWith(
      playerHand: [],
      dealerHand: [],
      currentBet: 0,
      status: BlackjackGameStatus.betting,
      dealerCardHidden: false,
      canHit: false,
      canStand: false,
      canDouble: false,
      canSplit: false,
      message: null,
    );
  }
}
