# Arena - Games Documentation

Welcome to the Arena games documentation! This directory contains comprehensive guides for all games available in the Airo super app.

## 📚 Game Categories

### 🎴 Card Games
- [Blackjack](card-games/blackjack.md) - ✅ Available
- [Texas Hold'em](card-games/texas-holdem.md) - 🔜 Coming Soon
- [Poker (5-Card Draw)](card-games/poker.md) - 🔜 Coming Soon
- [Rummy](card-games/rummy.md) - 🔜 Coming Soon
- [Solitaire (Klondike)](card-games/solitaire.md) - 🔜 Coming Soon

### ♟️ Board Games
- [Chess](board-games/chess.md) - ✅ Available

## 🎯 Quick Reference

| Game | Category | Players | Difficulty | Status |
|------|----------|---------|------------|--------|
| Blackjack | Card | 1-5 | Medium | ✅ Available |
| Texas Hold'em | Card | 2-9 | Hard | 🔜 Coming Soon |
| Poker | Card | 2-8 | Medium | 🔜 Coming Soon |
| Rummy | Card | 2-6 | Medium | 🔜 Coming Soon |
| Solitaire | Card | 1 | Easy | 🔜 Coming Soon |
| Chess | Board | 2 | Hard | ✅ Available |

## 🛠️ Technical Implementation

All games use a unified data model (`GameInfo`) for scalability and consistency:

```dart
class GameInfo {
  final String id;
  final String name;
  final String description;
  final GameCategory category;
  final int minPlayers;
  final int maxPlayers;
  final GameDifficulty difficulty;
  final List<String> rules;
  final List<String> howToPlay;
  final String objective;
  final bool isAvailable;
  // ... more fields
}
```

### Game Categories
- `card` - Card games using Deck of Cards API
- `board` - Board games (Chess, Checkers, etc.)
- `puzzle` - Puzzle games
- `strategy` - Strategy games
- `arcade` - Arcade games
- `casual` - Casual games

### Difficulty Levels
- `easy` - Simple rules, quick to learn
- `medium` - Moderate complexity
- `hard` - Complex strategy required

## 🎮 How to Add a New Game

1. Add game definition to `GameRegistry` in `app/lib/features/games/domain/models/game_info.dart`
2. Create game documentation in appropriate category folder
3. Implement game logic (state model, notifier, screen)
4. Update routing in `games_hub_screen.dart`
5. Set `isAvailable: true` when ready to launch

## 📖 Documentation Structure

Each game documentation includes:
- **Overview** - Brief description
- **Objective** - What players are trying to achieve
- **Rules** - Complete game rules
- **How to Play** - Step-by-step instructions
- **Player Count** - Min/max players
- **Difficulty** - Easy/Medium/Hard
- **Implementation Status** - Available or Coming Soon
- **API References** - For card games using Deck of Cards API

## 🔗 External Resources

- [Deck of Cards API](https://deckofcardsapi.com/) - Used for all card games
- [Flutter Documentation](https://flutter.dev/docs)
- [Riverpod State Management](https://riverpod.dev/)

## 📝 License

All game rules are based on standard game rules and are in the public domain.

