# Chess Master - Feature Documentation

## Overview

Chess Master is a fully-featured chess game with AI opponent, reactive audio system, and competitive banter. The game features voice lines for each piece type, reactive background music, and a sophisticated move classification system.

## Architecture

### Domain Layer

#### Models (`domain/models/chess_models.dart`)
- **PieceType**: Enum for chess pieces (pawn, knight, bishop, rook, queen, king)
- **ChessColor**: Enum for piece colors (white, black)
- **ChessPiece**: Represents a single piece with type and color
- **ChessSquare**: Board position (0-63 index, with file/rank helpers)
- **ChessMove**: Move from one square to another, with optional promotion
- **MoveClassification**: Enum for move types (quiet, capture, check, checkmate, blunder, brilliance)
- **ChessBoardState**: Complete board state including castling rights, en passant, move history
- **ChessGameState**: Game state with result tracking

#### Services

**ChessEngine** (`domain/services/chess_engine.dart`)
- Abstract interface for chess logic
- Methods: getLegalMoves(), makeMove(), undoMove(), getBestMove(), evaluatePosition()
- Status checks: isCheckmate(), isCheck(), isStalemate()
- FEN support: toFEN(), fromFEN()
- **FakeChessEngine**: Development implementation with basic move generation

**ChessAudioManager** (`domain/services/chess_audio_manager.dart`)
- Abstract interface for audio playback
- Voice line playback with tone selection (smug, sarcastic, dramatic, annoyed, victory, despair)
- Background music management (calm opening, midgame tension, endgame heroic)
- Stinger playback (capture, check, checkmate)
- Settings: toggles for voice/music, volume control
- **FakeChessAudioManager**: Development implementation with logging

**MoveEventDispatcher** (`domain/services/move_event_dispatcher.dart`)
- Event-driven architecture for move handling
- Move classification based on board state and evaluation
- Cooldown management (per-piece and global)
- Listener pattern for audio system integration
- Prevents audio spam with configurable cooldowns

### Presentation Layer

**ChessGameScreen** (`presentation/screens/chess_game_screen.dart`)
- Full chess UI with 8x8 board
- Square selection and legal move highlighting
- Piece symbols using Unicode chess characters
- Move history and game status display
- Settings dialog for audio toggles
- Undo and new game buttons

**GamesHubScreen** (`presentation/screens/games_hub_screen.dart`)
- Games hub with Chess Master featured
- Game tile with description
- Launch chess game via modal bottom sheet

## Audio System

### Voice Lines

Each piece type has 100+ lines minimum across different tones:

```
Pawn:   "A footsoldier did that.", "Pawn power.", "One step at a time."
Knight: "Two problems. One horse.", "Knight moves in mysterious ways."
Bishop: "Geometry hurts.", "Diagonal domination."
Rook:   "Corridor secured.", "Straight and narrow."
Queen:  "The queen reigns supreme.", "Royal flush."
King:   "That tickled.", "The king moves."
```

### Background Music

Reactive to game state:
- **Opening** (moves 1-10): Calm, exploratory
- **Midgame** (moves 11-30): Tension building
- **Endgame** (moves 30+): Heroic, dramatic

### Stingers

- Capture: Sharp, decisive sound
- Check: Alert, warning sound
- Checkmate: Victory fanfare

## Move Classification

Moves are classified based on:
1. **Checkmate**: Game-ending move
2. **Check**: King under attack
3. **Capture**: Piece taken
4. **Blunder**: Evaluation drop > 200 centipawns
5. **Brilliance**: Evaluation gain > 200 centipawns
6. **Quiet**: Normal move

## Cooldown System

Prevents audio spam:
- **Per-piece cooldown**: 500ms between voice lines for same piece
- **Global cooldown**: 300ms between any audio events
- Configurable via MoveEventDispatcher

## Settings

- **Voice Lines Toggle**: Enable/disable piece voice lines
- **Music Toggle**: Enable/disable background music
- **Volume Control**: 0.0 - 1.0 scale
- **Subtitle Mode**: Accessibility feature (planned)

## Integration Points

### With Riverpod

Providers can be created for:
- Chess engine state
- Audio manager state
- Game session tracking
- Highscores and achievements

### With Drift Database

Tables for:
- game_sessions: Game history
- moves: Move records with timestamps
- achievements: Unlocked achievements

### With Hive Cache

Boxes for:
- game_state: Current game snapshot
- audio_preferences: User audio settings
- move_cache: Recent moves for quick access

## Performance Considerations

- Audio preloaded at game start
- No network required for single-player
- Engine evaluation depth capped for mobile thermals
- Efficient board representation (64-element array)
- Move generation optimized per piece type

## Future Enhancements

1. **Real Chess Engine**: Integrate Stockfish mobile build
2. **Multiplayer**: Online turn-based with fast reconnect
3. **Cosmetic Skins**: Piece appearance customization
4. **Emotes**: Non-chat communication system
5. **Achievements**: Unlock-based progression
6. **Leaderboard**: Global ranking system
7. **Replay System**: Save and review games
8. **Opening Book**: Common opening sequences

## Testing

Unit tests should cover:
- Move generation for each piece type
- Board state transitions
- Checkmate/stalemate detection
- Audio event dispatching
- Cooldown enforcement

Widget tests should cover:
- Board rendering
- Square selection
- Move execution
- Settings dialog

## Security

- No third-party voice packs (prevents abuse)
- Local-only processing (no data transmission)
- No chat system (emotes only for multiplayer)
- Encrypted game state if stored

## Accessibility

- Subtitle mode for voice lines
- High contrast board option
- Keyboard navigation support (planned)
- Screen reader compatibility (planned)

