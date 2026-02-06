import 'card_model.dart';

/// Texas Hold'em game phases
enum TexasHoldemPhase { preflop, flop, turn, river, showdown, gameOver }

/// Player in Texas Hold'em
class TexasHoldemPlayer {
  final String id;
  final String name;
  final int chips;
  final List<CardModel> holeCards;
  final int currentBet;
  final bool isFolded;
  final bool isAllIn;
  final bool isDealer;
  final bool isSmallBlind;
  final bool isBigBlind;

  const TexasHoldemPlayer({
    required this.id,
    required this.name,
    required this.chips,
    required this.holeCards,
    this.currentBet = 0,
    this.isFolded = false,
    this.isAllIn = false,
    this.isDealer = false,
    this.isSmallBlind = false,
    this.isBigBlind = false,
  });

  TexasHoldemPlayer copyWith({
    String? id,
    String? name,
    int? chips,
    List<CardModel>? holeCards,
    int? currentBet,
    bool? isFolded,
    bool? isAllIn,
    bool? isDealer,
    bool? isSmallBlind,
    bool? isBigBlind,
  }) {
    return TexasHoldemPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      chips: chips ?? this.chips,
      holeCards: holeCards ?? this.holeCards,
      currentBet: currentBet ?? this.currentBet,
      isFolded: isFolded ?? this.isFolded,
      isAllIn: isAllIn ?? this.isAllIn,
      isDealer: isDealer ?? this.isDealer,
      isSmallBlind: isSmallBlind ?? this.isSmallBlind,
      isBigBlind: isBigBlind ?? this.isBigBlind,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'chips': chips,
      'holeCards': holeCards.map((c) => c.toJson()).toList(),
      'currentBet': currentBet,
      'isFolded': isFolded,
      'isAllIn': isAllIn,
      'isDealer': isDealer,
      'isSmallBlind': isSmallBlind,
      'isBigBlind': isBigBlind,
    };
  }

  factory TexasHoldemPlayer.fromJson(Map<String, dynamic> json) {
    return TexasHoldemPlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      chips: json['chips'] as int,
      holeCards: (json['holeCards'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      currentBet: json['currentBet'] as int? ?? 0,
      isFolded: json['isFolded'] as bool? ?? false,
      isAllIn: json['isAllIn'] as bool? ?? false,
      isDealer: json['isDealer'] as bool? ?? false,
      isSmallBlind: json['isSmallBlind'] as bool? ?? false,
      isBigBlind: json['isBigBlind'] as bool? ?? false,
    );
  }
}

/// Texas Hold'em game state
class TexasHoldemGame {
  final String deckId;
  final List<TexasHoldemPlayer> players;
  final List<CardModel> communityCards;
  final int pot;
  final TexasHoldemPhase phase;
  final int currentBet;
  final int smallBlind;
  final int bigBlind;
  final int currentPlayerIndex;
  final int dealerIndex;
  final String? message;
  final String? winner;

  const TexasHoldemGame({
    required this.deckId,
    required this.players,
    required this.communityCards,
    required this.pot,
    required this.phase,
    required this.currentBet,
    required this.smallBlind,
    required this.bigBlind,
    required this.currentPlayerIndex,
    required this.dealerIndex,
    this.message,
    this.winner,
  });

  TexasHoldemGame copyWith({
    String? deckId,
    List<TexasHoldemPlayer>? players,
    List<CardModel>? communityCards,
    int? pot,
    TexasHoldemPhase? phase,
    int? currentBet,
    int? smallBlind,
    int? bigBlind,
    int? currentPlayerIndex,
    int? dealerIndex,
    String? message,
    String? winner,
  }) {
    return TexasHoldemGame(
      deckId: deckId ?? this.deckId,
      players: players ?? this.players,
      communityCards: communityCards ?? this.communityCards,
      pot: pot ?? this.pot,
      phase: phase ?? this.phase,
      currentBet: currentBet ?? this.currentBet,
      smallBlind: smallBlind ?? this.smallBlind,
      bigBlind: bigBlind ?? this.bigBlind,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      dealerIndex: dealerIndex ?? this.dealerIndex,
      message: message ?? this.message,
      winner: winner ?? this.winner,
    );
  }

  TexasHoldemPlayer get currentPlayer => players[currentPlayerIndex];

  bool get isPlayerTurn => currentPlayerIndex == 0 && !currentPlayer.isFolded;

  int get activePlayers =>
      players.where((p) => !p.isFolded && !p.isAllIn).length;

  Map<String, dynamic> toJson() {
    return {
      'deckId': deckId,
      'players': players.map((p) => p.toJson()).toList(),
      'communityCards': communityCards.map((c) => c.toJson()).toList(),
      'pot': pot,
      'phase': phase.name,
      'currentBet': currentBet,
      'smallBlind': smallBlind,
      'bigBlind': bigBlind,
      'currentPlayerIndex': currentPlayerIndex,
      'dealerIndex': dealerIndex,
      'message': message,
      'winner': winner,
    };
  }

  factory TexasHoldemGame.fromJson(Map<String, dynamic> json) {
    return TexasHoldemGame(
      deckId: json['deckId'] as String,
      players: (json['players'] as List)
          .map((p) => TexasHoldemPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      communityCards: (json['communityCards'] as List)
          .map((c) => CardModel.fromJson(c as Map<String, dynamic>))
          .toList(),
      pot: json['pot'] as int,
      phase: TexasHoldemPhase.values.firstWhere(
        (e) => e.name == json['phase'],
        orElse: () => TexasHoldemPhase.preflop,
      ),
      currentBet: json['currentBet'] as int,
      smallBlind: json['smallBlind'] as int,
      bigBlind: json['bigBlind'] as int,
      currentPlayerIndex: json['currentPlayerIndex'] as int,
      dealerIndex: json['dealerIndex'] as int,
      message: json['message'] as String?,
      winner: json['winner'] as String?,
    );
  }
}
