# Chess Agent Tasks

## Branch: agent/chess/fix-cpu-and-ux

## Status: ✅ Complete

---

## Task 1: Fix CPU Move Correctness ✅
**Status:** Completed

### Summary
Added comprehensive unit tests covering chess engine edge cases. The existing implementation using `chess` package (chess.dart) and `stockfish` package already handles all edge cases correctly.

### Tests Added
- ✅ Castling (kingside & queenside, both colors)
- ✅ En-passant captures
- ✅ Pawn promotions (all piece types)
- ✅ Stalemate detection
- ✅ Checkmate detection
- ✅ Check detection

### Design Decisions
- Used `RealChessEngine` wrapper around chess.dart library
- Tests verify the engine correctly delegates to chess.dart for move validation
- All edge cases pass without code changes (library handles them correctly)

---

## Task 2: Shuffle Sides Option ✅
**Status:** Completed

### Summary
Added toggle in difficulty selection screen to randomly assign white/black on game start.

### Changes
- Added `shuffleSides` parameter to `ChessGameFlame` constructor
- Added toggle switch in difficulty selection UI
- Player color randomly assigned when `shuffleSides` is true
- AI moves first if player is assigned black
- Updated widget tests

### Design Decisions
- Toggle is OFF by default (player always white, traditional chess experience)
- Random assignment uses `Random().nextBool()` for 50/50 split
- Board auto-flips based on player color for correct perspective

---

## Task 3: Board Flip ✅
**Status:** Completed

### Summary
Added flip button in app bar to flip board perspective. Coordinates, input handling, and rendering respect flipped view.

### Changes
- Added flip icon button in game app bar
- Added `isBoardFlipped` state variable
- Updated `_drawBoard()` to respect flip state
- Updated `_drawPieces()` to respect flip state
- Updated `_drawCoordinates()` to respect flip state
- Updated `onTapDown()` input handling for flipped board
- Added widget tests for flip functionality

### Design Decisions
- Flip is independent of player color (can flip regardless of side)
- Flip button uses Icons.swap_vert for clear visual indication
- Board flip is purely visual - does not affect game logic

---

## Task 4: Voice Move Announcements ✅
**Status:** Completed

### Summary
Added voice move announcements that speak moves in human-readable format (e.g., "Knight to f3").

### Changes
- Added `speakMoveNotation()` method to `ChessTTSManager`
- Added `_getPieceName()` helper for piece type to name conversion
- Move announcement plays BEFORE DotA banter (so user hears "Knight to f3" then banter)
- Added unit tests with `FakeTTSClient` for testing without actual TTS

### Design Decisions
- Format: "[Piece] to [square]" for moves, "[Piece] takes on [square]" for captures
- Special cases: "Castles kingside", "Castles queenside"
- Promotions: "Pawn promotes to Queen on e8"
- Uses separate method from banter - both play in sequence
- Added `FakeTTSClient` interface for testability

---

## Run Commands

```bash
# Create/switch to branch
git checkout -b agent/chess/fix-cpu-and-ux

# Run tests
cd app && flutter test

# Run analyzer
flutter analyze

# Format code
dart format --set-exit-if-changed lib/ test/

# Local CI check
act
```

---

## Deliverables Checklist

- [x] Branch created: `agent/chess/fix-cpu-and-ux`
- [x] Unit tests for edge cases (castling, en-passant, promotions, stalemate)
- [x] Shuffle sides toggle in settings
- [x] Board flip button with correct coordinate handling
- [x] Voice move announcements
- [x] Widget tests for new UI features
- [x] All tests passing
- [x] No analyzer warnings
- [ ] PR created with description and screenshots

---

## Notes

- Chess engine uses `chess` package v0.8.1 (battle-tested, full FIDE rules)
- AI uses `stockfish` package v1.7.1 (strongest chess engine)
- TTS uses `flutter_tts` package v4.2.3
- Flame engine v1.33.0 for board rendering

