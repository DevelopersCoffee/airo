import 'package:flutter/material.dart';

/// Game category for organizing games
enum GameCategory {
  card('Card Games', Icons.casino),
  board('Board Games', Icons.grid_on),
  puzzle('Puzzle Games', Icons.extension),
  strategy('Strategy Games', Icons.psychology),
  arcade('Arcade Games', Icons.sports_esports),
  casual('Casual Games', Icons.games);

  final String displayName;
  final IconData icon;

  const GameCategory(this.displayName, this.icon);
}

/// Difficulty level for games
enum GameDifficulty {
  easy('Easy', Colors.green),
  medium('Medium', Colors.orange),
  hard('Hard', Colors.red);

  final String displayName;
  final Color color;

  const GameDifficulty(this.displayName, this.color);
}

/// Unified game information model for all game types
class GameInfo {
  final String id;
  final String name;
  final String description;
  final String shortDescription;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final GameDifficulty difficulty;
  final List<String> rules;
  final List<String> howToPlay;
  final String objective;
  final IconData? customIcon;
  final bool isAvailable;
  final String? routePath;
  final Map<String, dynamic>? metadata; // For game-specific data

  const GameInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.shortDescription,
    required this.category,
    required this.minPlayers,
    required this.maxPlayers,
    required this.difficulty,
    required this.rules,
    required this.howToPlay,
    required this.objective,
    this.customIcon,
    this.isAvailable = true,
    this.routePath,
    this.metadata,
  });

  /// Get icon for this game (custom or category default)
  IconData get icon => customIcon ?? category.icon;

  /// Get deck count for card games (from metadata)
  int get deckCount => metadata?['deckCount'] ?? 1;

  /// Check if this is a multiplayer game
  bool get isMultiplayer => maxPlayers > 1;

  /// Check if this is a single-player game
  bool get isSinglePlayer => minPlayers == 1 && maxPlayers == 1;

  /// Get player count display string
  String get playerCountDisplay {
    if (isSinglePlayer) return 'Single Player';
    if (minPlayers == maxPlayers) return '$minPlayers Players';
    return '$minPlayers-$maxPlayers Players';
  }
}

/// Registry of all available games
class GameRegistry {
  // ============================================================================
  // CARD GAMES
  // ============================================================================

  static const blackjack = GameInfo(
    id: 'blackjack',
    name: 'Blackjack',
    description:
        'Classic casino card game where you try to beat the dealer by getting as close to 21 as possible without going over.',
    shortDescription: 'Beat the dealer, get 21',
    category: GameCategory.card,
    minPlayers: 1,
    maxPlayers: 5,
    difficulty: GameDifficulty.easy,
    objective:
        'Get a hand value closer to 21 than the dealer without going over.',
    rules: [
      'Number cards (2-10) are worth their face value',
      'Face cards (Jack, Queen, King) are worth 10',
      'Aces are worth 1 or 11 (whichever is better)',
      'If you go over 21, you "bust" and lose',
      'Dealer must hit on 16 or less, stand on 17 or more',
      'Blackjack (Ace + 10-value card) pays 3:2',
    ],
    howToPlay: [
      '1. Place your bet by selecting chip amounts',
      '2. Tap "Deal" to receive 2 cards (dealer gets 2 cards, one hidden)',
      '3. Choose your action:',
      '   • Hit: Take another card',
      '   • Stand: Keep your current hand',
      '   • Double: Double your bet and take one more card',
      '4. Dealer reveals hidden card and plays',
      '5. Closest to 21 wins!',
    ],
    isAvailable: true,
    routePath: '/games/blackjack',
    metadata: {'deckCount': 1},
  );

  static const texasHoldem = GameInfo(
    id: 'texas_holdem',
    name: 'Texas Hold\'em',
    description:
        'The most popular poker variant where you make the best 5-card hand using 2 hole cards and 5 community cards.',
    shortDescription: 'Poker with community cards',
    category: GameCategory.card,
    minPlayers: 2,
    maxPlayers: 9,
    difficulty: GameDifficulty.hard,
    objective:
        'Win chips by making the best 5-card poker hand or bluffing opponents.',
    rules: [
      'Each player gets 2 private "hole" cards',
      '5 community cards are dealt face-up on the table',
      'Make the best 5-card hand using any combination',
      'Betting rounds: Pre-flop, Flop, Turn, River',
      'Hand rankings (high to low): Royal Flush, Straight Flush, Four of a Kind, Full House, Flush, Straight, Three of a Kind, Two Pair, Pair, High Card',
    ],
    howToPlay: [
      '1. Each player receives 2 hole cards',
      '2. First betting round (pre-flop)',
      '3. Flop: 3 community cards dealt, betting round',
      '4. Turn: 4th community card dealt, betting round',
      '5. River: 5th community card dealt, final betting',
      '6. Showdown: Best hand wins the pot',
    ],
    isAvailable: true,
    routePath: '/games/texas-holdem',
    metadata: {'deckCount': 1},
  );

  static const poker = GameInfo(
    id: 'poker',
    name: 'Poker (5-Card Draw)',
    description:
        'Classic poker where each player gets 5 cards and can exchange cards once.',
    shortDescription: 'Classic 5-card poker',
    category: GameCategory.card,
    minPlayers: 2,
    maxPlayers: 6,
    difficulty: GameDifficulty.medium,
    objective: 'Make the best 5-card poker hand to win the pot.',
    rules: [
      'Each player gets 5 cards face-down',
      'Betting round after initial deal',
      'Players can discard and draw new cards (once)',
      'Final betting round',
      'Best hand wins the pot',
    ],
    howToPlay: [
      '1. Each player receives 5 cards',
      '2. First betting round',
      '3. Discard unwanted cards and draw new ones',
      '4. Final betting round',
      '5. Showdown: Best hand wins',
    ],
    isAvailable: true,
    routePath: '/games/poker',
    metadata: {'deckCount': 1},
  );

  static const rummy = GameInfo(
    id: 'rummy',
    name: 'Rummy',
    description: 'Form sets and runs to reduce deadwood points.',
    shortDescription: 'Form sets and runs',
    category: GameCategory.card,
    minPlayers: 2,
    maxPlayers: 6,
    difficulty: GameDifficulty.medium,
    objective: 'Form melds (sets/runs) and reduce deadwood to knock or go out.',
    rules: [
      'Sets: 3-4 cards of same rank',
      'Runs: 3+ cards of same suit in sequence',
      'Draw from deck or discard pile',
      'Discard one card each turn',
      'First to meld all cards wins',
    ],
    howToPlay: [
      '1. Each player gets 7-10 cards',
      '2. Draw from deck or discard pile',
      '3. Form sets or runs',
      '4. Discard one card',
      '5. First to meld all cards wins',
    ],
    isAvailable: true,
    routePath: '/games/rummy',
    metadata: {'deckCount': 1},
  );

  static const solitaire = GameInfo(
    id: 'solitaire',
    name: 'Solitaire',
    description:
        'Classic single-player game where you build foundations from Ace to King.',
    shortDescription: 'Build foundations Ace to King',
    category: GameCategory.card,
    minPlayers: 1,
    maxPlayers: 1,
    difficulty: GameDifficulty.medium,
    objective: 'Move all cards to 4 foundation piles (Ace to King by suit).',
    rules: [
      'Foundations: Build up by suit (A→2→3...→K)',
      'Tableau: Build down by alternating colors',
      'Only Kings can fill empty tableau columns',
      'Draw 1 or 3 cards from stock pile',
      'Can move sequences of cards in tableau',
    ],
    howToPlay: [
      '1. Deal 7 tableau piles (1-7 cards, top card face-up)',
      '2. Move Aces to foundations as they appear',
      '3. Build foundations up by suit',
      '4. Build tableau down by alternating colors',
      '5. Draw from stock when stuck',
      '6. Win by moving all cards to foundations',
    ],
    isAvailable: true,
    routePath: '/games/solitaire',
    metadata: {'deckCount': 1},
  );

  // ============================================================================
  // BOARD GAMES
  // ============================================================================

  static const chess = GameInfo(
    id: 'chess',
    name: 'Chess',
    description:
        'Classic strategy board game where you checkmate your opponent\'s king.',
    shortDescription: 'Checkmate the king',
    category: GameCategory.board,
    minPlayers: 2,
    maxPlayers: 2,
    difficulty: GameDifficulty.hard,
    objective: 'Checkmate your opponent\'s king.',
    rules: [
      'Each piece moves differently (pawns, knights, bishops, rooks, queens, kings)',
      'Capture opponent pieces by moving to their square',
      'Check: King is under attack',
      'Checkmate: King is in check with no escape',
      'Stalemate: No legal moves but not in check (draw)',
      'Castling: Special king + rook move (once per game)',
      'En passant: Special pawn capture',
    ],
    howToPlay: [
      '1. White moves first',
      '2. Players alternate turns',
      '3. Move one piece per turn',
      '4. Capture opponent pieces',
      '5. Protect your king',
      '6. Checkmate opponent to win',
    ],
    isAvailable: true,
    routePath: '/games/chess',
  );

  // ============================================================================
  // ALL GAMES REGISTRY
  // ============================================================================

  static final List<GameInfo> all = [
    // Card Games
    blackjack,
    texasHoldem,
    poker,
    rummy,
    solitaire,

    // Board Games
    chess,
  ];

  static final List<GameInfo> available = all
      .where((game) => game.isAvailable)
      .toList();

  static Map<GameCategory, List<GameInfo>> get byCategory {
    final map = <GameCategory, List<GameInfo>>{};
    for (final game in all) {
      map.putIfAbsent(game.category, () => []).add(game);
    }
    return map;
  }

  static GameInfo? findById(String id) {
    try {
      return all.firstWhere((game) => game.id == id);
    } catch (_) {
      return null;
    }
  }
}
