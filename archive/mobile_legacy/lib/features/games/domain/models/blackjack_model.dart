import 'card_model.dart';

/// Blackjack game state
class BlackjackGame {
  final String deckId;
  final List<CardModel> playerHand;
  final List<CardModel> dealerHand;
  final int playerBalance;
  final int currentBet;
  final BlackjackGameStatus status;
  final int remainingCards;
  final bool dealerCardHidden;
  final bool canDouble;
  final bool canSplit;
  final bool canHit;
  final bool canStand;
  final String? message;

  const BlackjackGame({
    required this.deckId,
    required this.playerHand,
    required this.dealerHand,
    required this.playerBalance,
    required this.currentBet,
    required this.status,
    required this.remainingCards,
    this.dealerCardHidden = false,
    this.canDouble = false,
    this.canSplit = false,
    this.canHit = false,
    this.canStand = false,
    this.message,
  });

  BlackjackGame copyWith({
    String? deckId,
    List<CardModel>? playerHand,
    List<CardModel>? dealerHand,
    int? playerBalance,
    int? currentBet,
    BlackjackGameStatus? status,
    int? remainingCards,
    bool? dealerCardHidden,
    bool? canDouble,
    bool? canSplit,
    bool? canHit,
    bool? canStand,
    String? message,
  }) {
    return BlackjackGame(
      deckId: deckId ?? this.deckId,
      playerHand: playerHand ?? this.playerHand,
      dealerHand: dealerHand ?? this.dealerHand,
      playerBalance: playerBalance ?? this.playerBalance,
      currentBet: currentBet ?? this.currentBet,
      status: status ?? this.status,
      remainingCards: remainingCards ?? this.remainingCards,
      dealerCardHidden: dealerCardHidden ?? this.dealerCardHidden,
      canDouble: canDouble ?? this.canDouble,
      canSplit: canSplit ?? this.canSplit,
      canHit: canHit ?? this.canHit,
      canStand: canStand ?? this.canStand,
      message: message ?? this.message,
    );
  }

  factory BlackjackGame.fromJson(Map<String, dynamic> json) {
    return BlackjackGame(
      deckId: json['deckId'] as String,
      playerHand: (json['playerHand'] as List<dynamic>)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      dealerHand: (json['dealerHand'] as List<dynamic>)
          .map((e) => CardModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      playerBalance: json['playerBalance'] as int,
      currentBet: json['currentBet'] as int,
      status: BlackjackGameStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
      ),
      remainingCards: json['remainingCards'] as int,
      dealerCardHidden: json['dealerCardHidden'] as bool? ?? false,
      canDouble: json['canDouble'] as bool? ?? false,
      canSplit: json['canSplit'] as bool? ?? false,
      canHit: json['canHit'] as bool? ?? false,
      canStand: json['canStand'] as bool? ?? false,
      message: json['message'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deckId': deckId,
      'playerHand': playerHand.map((e) => e.toJson()).toList(),
      'dealerHand': dealerHand.map((e) => e.toJson()).toList(),
      'playerBalance': playerBalance,
      'currentBet': currentBet,
      'status': status.toString().split('.').last,
      'remainingCards': remainingCards,
      'dealerCardHidden': dealerCardHidden,
      'canDouble': canDouble,
      'canSplit': canSplit,
      'canHit': canHit,
      'canStand': canStand,
      if (message != null) 'message': message,
    };
  }
}

/// Blackjack game status
enum BlackjackGameStatus {
  betting,
  playing,
  dealerTurn,
  playerWin,
  dealerWin,
  push,
  blackjack,
  bust,
}

/// Blackjack game settings
class BlackjackSettings {
  final int deckCount;
  final bool dealerHitsSoft17;
  final BlackjackPayout blackjackPayout;
  final int startingBalance;
  final int minimumBet;
  final int maximumBet;

  const BlackjackSettings({
    this.deckCount = 1,
    this.dealerHitsSoft17 = true,
    this.blackjackPayout = BlackjackPayout.threeToTwo,
    this.startingBalance = 1000,
    this.minimumBet = 10,
    this.maximumBet = 500,
  });

  BlackjackSettings copyWith({
    int? deckCount,
    bool? dealerHitsSoft17,
    BlackjackPayout? blackjackPayout,
    int? startingBalance,
    int? minimumBet,
    int? maximumBet,
  }) {
    return BlackjackSettings(
      deckCount: deckCount ?? this.deckCount,
      dealerHitsSoft17: dealerHitsSoft17 ?? this.dealerHitsSoft17,
      blackjackPayout: blackjackPayout ?? this.blackjackPayout,
      startingBalance: startingBalance ?? this.startingBalance,
      minimumBet: minimumBet ?? this.minimumBet,
      maximumBet: maximumBet ?? this.maximumBet,
    );
  }

  factory BlackjackSettings.fromJson(Map<String, dynamic> json) {
    return BlackjackSettings(
      deckCount: json['deckCount'] as int? ?? 1,
      dealerHitsSoft17: json['dealerHitsSoft17'] as bool? ?? true,
      blackjackPayout: json['blackjackPayout'] != null
          ? BlackjackPayout.values.firstWhere(
              (e) => e.toString().split('.').last == json['blackjackPayout'],
            )
          : BlackjackPayout.threeToTwo,
      startingBalance: json['startingBalance'] as int? ?? 1000,
      minimumBet: json['minimumBet'] as int? ?? 10,
      maximumBet: json['maximumBet'] as int? ?? 500,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'deckCount': deckCount,
      'dealerHitsSoft17': dealerHitsSoft17,
      'blackjackPayout': blackjackPayout.toString().split('.').last,
      'startingBalance': startingBalance,
      'minimumBet': minimumBet,
      'maximumBet': maximumBet,
    };
  }
}

/// Blackjack payout ratio
enum BlackjackPayout {
  threeToTwo, // Traditional: pays 1.5x
  sixToFive, // Modern: pays 1.2x
}

extension BlackjackPayoutExtension on BlackjackPayout {
  double get multiplier {
    switch (this) {
      case BlackjackPayout.threeToTwo:
        return 1.5;
      case BlackjackPayout.sixToFive:
        return 1.2;
    }
  }
}

/// Calculate hand value for Blackjack
class BlackjackHandCalculator {
  /// Calculate the best value for a hand (handles Aces as 1 or 11)
  static int calculateHandValue(List<CardModel> hand) {
    int value = 0;
    int aces = 0;

    for (final card in hand) {
      if (card.value == 'ACE') {
        aces++;
        value += 11;
      } else if (['JACK', 'QUEEN', 'KING'].contains(card.value)) {
        value += 10;
      } else {
        value += int.tryParse(card.value) ?? 0;
      }
    }

    // Adjust for Aces if value is over 21
    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }

    return value;
  }

  /// Check if hand is a blackjack (21 with 2 cards)
  static bool isBlackjack(List<CardModel> hand) {
    return hand.length == 2 && calculateHandValue(hand) == 21;
  }

  /// Check if hand is bust (over 21)
  static bool isBust(List<CardModel> hand) {
    return calculateHandValue(hand) > 21;
  }

  /// Check if hand is soft (has an Ace counted as 11)
  static bool isSoft(List<CardModel> hand) {
    int value = 0;
    bool hasAce = false;

    for (final card in hand) {
      if (card.value == 'ACE') {
        hasAce = true;
        value += 11;
      } else if (['JACK', 'QUEEN', 'KING'].contains(card.value)) {
        value += 10;
      } else {
        value += int.tryParse(card.value) ?? 0;
      }
    }

    return hasAce && value <= 21;
  }

  /// Check if hand can be split (two cards of same value)
  static bool canSplit(List<CardModel> hand) {
    if (hand.length != 2) return false;

    final value1 = _getCardNumericValue(hand[0]);
    final value2 = _getCardNumericValue(hand[1]);

    return value1 == value2;
  }

  static int _getCardNumericValue(CardModel card) {
    if (card.value == 'ACE') return 11;
    if (['JACK', 'QUEEN', 'KING'].contains(card.value)) return 10;
    return int.tryParse(card.value) ?? 0;
  }
}
