# Chess

## Overview

Chess is a two-player strategy board game played on an 8x8 checkered board. Each player controls 16 pieces with the goal of checkmating the opponent's king.

**Status:** ✅ Available  
**Players:** 2  
**Difficulty:** Hard  
**Board:** 8x8 checkered board (64 squares)

## Objective

Checkmate your opponent's king by placing it under attack with no legal moves to escape.

## Rules

### The Board
- 8x8 grid with alternating light and dark squares
- Files (columns) labeled a-h from left to right
- Ranks (rows) labeled 1-8 from bottom to top
- Each player starts with pieces on ranks 1-2 (White) and 7-8 (Black)
- Light square always on the right for each player

### The Pieces

Each player starts with:
- **1 King (K):** Most important piece
- **1 Queen (Q):** Most powerful piece
- **2 Rooks (R):** Castle-shaped pieces
- **2 Bishops (B):** Diagonal movers
- **2 Knights (N):** L-shaped movers
- **8 Pawns (P):** Front-line pieces

### How Pieces Move

**King (K):**
- Moves one square in any direction
- Cannot move into check
- Can castle once per game (special move)

**Queen (Q):**
- Moves any number of squares in any direction (horizontal, vertical, diagonal)
- Most powerful piece
- Cannot jump over pieces

**Rook (R):**
- Moves any number of squares horizontally or vertically
- Cannot jump over pieces
- Used in castling

**Bishop (B):**
- Moves any number of squares diagonally
- Cannot jump over pieces
- Each bishop stays on its starting color

**Knight (N):**
- Moves in an "L" shape: 2 squares in one direction, 1 square perpendicular
- Only piece that can jump over other pieces
- Alternates between light and dark squares

**Pawn (P):**
- Moves forward one square (or two squares on first move)
- Captures diagonally forward one square
- Promotes to any piece (usually Queen) when reaching the opposite end
- Can capture "en passant" (special pawn capture)

## How to Play

### Step 1: Setup
- Place board with light square on bottom right
- White pieces on ranks 1-2, Black on ranks 7-8
- Rooks in corners, Knights next to them, Bishops next to Knights
- Queen on her color (White Queen on light square, Black Queen on dark square)
- King on remaining center square
- Pawns on second rank

### Step 2: Starting the Game
- White always moves first
- Players alternate turns
- Each turn, move one piece (except castling)

### Step 3: Making Moves
- Select a piece and move it according to its movement rules
- Capture opponent's pieces by moving to their square
- Cannot capture your own pieces
- Cannot move into check
- Must move out of check if in check

### Step 4: Special Moves

**Castling:**
- King and Rook move simultaneously
- King moves 2 squares toward Rook
- Rook moves to square King crossed
- Requirements:
  - Neither piece has moved before
  - No pieces between them
  - King not in check
  - King doesn't cross or land in check
- Kingside (short) castling: King to g-file
- Queenside (long) castling: King to c-file

**En Passant:**
- Special pawn capture
- When opponent's pawn moves 2 squares forward from starting position
- And lands beside your pawn
- You can capture it as if it moved only 1 square
- Must be done immediately on next turn

**Pawn Promotion:**
- When pawn reaches opposite end (rank 8 for White, rank 1 for Black)
- Must promote to Queen, Rook, Bishop, or Knight
- Usually promote to Queen (most powerful)
- New piece takes effect immediately

### Step 5: Check and Checkmate

**Check:**
- King is under attack
- Must move king, block attack, or capture attacking piece
- Cannot make a move that leaves king in check

**Checkmate:**
- King is in check
- No legal move can get king out of check
- Game over, attacking player wins

**Stalemate:**
- Player has no legal moves
- King is NOT in check
- Game ends in a draw

### Step 6: Winning the Game

**Win by:**
- Checkmate
- Opponent resigns
- Opponent runs out of time (in timed games)

**Draw by:**
- Stalemate
- Mutual agreement
- Threefold repetition (same position 3 times)
- 50-move rule (50 moves without capture or pawn move)
- Insufficient material (e.g., King vs King)

## Strategy Tips

### Opening Principles
1. **Control the center** - Place pawns and pieces in center squares (d4, d5, e4, e5)
2. **Develop pieces** - Move Knights and Bishops out early
3. **Castle early** - Protect your King
4. **Don't move same piece twice** - Develop all pieces
5. **Don't bring Queen out too early** - Can be attacked and chased

### Middle Game
1. **Look for tactics** - Forks, pins, skewers, discovered attacks
2. **Control key squares** - Outposts for Knights, open files for Rooks
3. **Coordinate pieces** - Work together to attack
4. **Pawn structure** - Avoid weak pawns, create passed pawns
5. **King safety** - Keep King protected

### End Game
1. **Activate King** - King becomes strong in endgame
2. **Passed pawns** - Push pawns toward promotion
3. **Rook activity** - Rooks on 7th rank are powerful
4. **Opposition** - King positioning in pawn endgames
5. **Calculate precisely** - Every move matters

### Common Tactics
- **Fork:** One piece attacks two or more pieces
- **Pin:** Piece cannot move without exposing more valuable piece
- **Skewer:** Valuable piece must move, exposing less valuable piece
- **Discovered attack:** Moving one piece reveals attack from another
- **Double attack:** Two pieces attack simultaneously
- **Sacrifice:** Give up material for positional advantage or checkmate

## Implementation Details

### Current Features
- ✅ 8x8 chess board display
- ✅ All piece movements implemented
- ✅ Turn-based gameplay
- ✅ Check detection
- ✅ Checkmate detection
- ✅ Stalemate detection
- ✅ Castling
- ✅ En passant
- ✅ Pawn promotion
- ✅ Move validation
- ✅ Game state management

### Planned Features
- 🔜 AI opponent with difficulty levels
- 🔜 Move history and notation
- 🔜 Undo/Redo moves
- 🔜 Save/Load games
- 🔜 Timer (Blitz, Rapid, Classical)
- 🔜 Hints and analysis
- 🔜 Opening book
- 🔜 Puzzles and tactics trainer
- 🔜 Online multiplayer
- 🔜 Game analysis with engine

### Technical Implementation
```dart
class ChessGame {
  final List<List<ChessPiece?>> board; // 8x8 grid
  final ChessColor currentTurn;
  final bool whiteKingMoved;
  final bool blackKingMoved;
  final bool whiteKingsideRookMoved;
  final bool whiteQueensideRookMoved;
  final bool blackKingsideRookMoved;
  final bool blackQueensideRookMoved;
  final ChessPosition? enPassantTarget;
  final List<ChessMove> moveHistory;
  final ChessGameStatus status;
}

class ChessPiece {
  final ChessPieceType type;
  final ChessColor color;
}

enum ChessPieceType { king, queen, rook, bishop, knight, pawn }
enum ChessColor { white, black }
enum ChessGameStatus { ongoing, check, checkmate, stalemate, draw }
```

### Algorithms Implemented
1. **Move Generation:** Calculate all legal moves for each piece
2. **Check Detection:** Determine if king is under attack
3. **Checkmate Detection:** Verify no legal moves escape check
4. **Stalemate Detection:** Verify no legal moves but not in check
5. **Castling Validation:** Check all castling requirements
6. **En Passant Detection:** Track pawn double-moves
7. **Pawn Promotion:** Handle pawn reaching end rank

## Chess Notation

### Algebraic Notation
- **Pieces:** K (King), Q (Queen), R (Rook), B (Bishop), N (Knight), Pawn (no letter)
- **Files:** a-h (columns)
- **Ranks:** 1-8 (rows)
- **Move:** Piece + destination square (e.g., Nf3, e4)
- **Capture:** x (e.g., Bxf7, exd5)
- **Check:** + (e.g., Qh5+)
- **Checkmate:** # (e.g., Qh7#)
- **Castling kingside:** O-O
- **Castling queenside:** O-O-O
- **Promotion:** = (e.g., e8=Q)

### Example Game
```
1. e4 e5
2. Nf3 Nc6
3. Bb5 a6
4. Ba4 Nf6
5. O-O Be7
6. Re1 b5
7. Bb3 d6
8. c3 O-O
```

## Glossary

- **Check:** King is under attack
- **Checkmate:** King is in check with no escape (game over)
- **Stalemate:** No legal moves but not in check (draw)
- **Castling:** Special King and Rook move
- **En Passant:** Special pawn capture
- **Promotion:** Pawn reaching opposite end becomes another piece
- **Fork:** One piece attacks multiple pieces
- **Pin:** Piece cannot move without exposing valuable piece
- **Skewer:** Valuable piece must move, exposing another
- **Discovered attack:** Moving reveals attack from another piece
- **Sacrifice:** Giving up material for advantage
- **Gambit:** Sacrificing material in opening for position
- **Endgame:** Final phase with few pieces remaining
- **Opening:** First phase of the game
- **Middle game:** Main phase between opening and endgame

## References

- [Chess Rules - Wikipedia](https://en.wikipedia.org/wiki/Rules_of_chess)
- [Chess.com Learn](https://www.chess.com/learn-how-to-play-chess)
- [Lichess Practice](https://lichess.org/practice)
- [FIDE Laws of Chess](https://www.fide.com/FIDE/handbook/LawsOfChess.pdf)

