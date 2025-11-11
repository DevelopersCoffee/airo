# Solitaire (Klondike)

## Overview

Klondike Solitaire is the classic single-player card game where you build foundation piles from Ace to King by suit, using a tableau of seven columns.

**Status:** 🔜 Coming Soon  
**Players:** 1  
**Difficulty:** Easy  
**Deck:** 1 standard 52-card deck

## Objective

Move all 52 cards to the four foundation piles, building each suit from Ace to King.

## Rules

### Layout
**Tableau:** Seven columns of cards
- Column 1: 1 card (face up)
- Column 2: 2 cards (1 face down, 1 face up)
- Column 3: 3 cards (2 face down, 1 face up)
- Column 4: 4 cards (3 face down, 1 face up)
- Column 5: 5 cards (4 face down, 1 face up)
- Column 6: 6 cards (5 face down, 1 face up)
- Column 7: 7 cards (6 face down, 1 face up)

**Stock:** Remaining 24 cards face down

**Waste:** Cards drawn from stock

**Foundation:** Four empty piles (one for each suit)

### Building Rules
**Tableau:**
- Build down in alternating colors
- Example: Red 7 on Black 8, Black 6 on Red 7
- Only Kings can be placed in empty columns
- Can move sequences of cards together

**Foundation:**
- Build up by suit from Ace to King
- Example: A♠, 2♠, 3♠, 4♠, etc.
- Must start with Ace

### Moving Cards
1. **Tableau to Tableau:** Build down, alternating colors
2. **Tableau to Foundation:** Build up by suit
3. **Stock to Waste:** Draw cards (1 or 3 at a time)
4. **Waste to Tableau:** Top card only
5. **Waste to Foundation:** Top card only
6. **Foundation to Tableau:** Allowed but rarely useful

## How to Play

### Step 1: Setup
- Deal 28 cards into 7 tableau columns as described above
- Place remaining 24 cards face down as stock
- Leave space for 4 foundation piles

### Step 2: Make Initial Moves
- Look for Aces to start foundation piles
- Build down on tableau in alternating colors
- Flip face-down cards when top card is moved

### Step 3: Draw from Stock
- Click stock to draw cards to waste pile
- **Draw 1 mode:** Draw one card at a time
- **Draw 3 mode:** Draw three cards at a time (harder)
- Can cycle through stock unlimited times

### Step 4: Build Foundations
- Move Aces to foundation piles immediately
- Build up each suit: A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K
- Double-click cards to auto-move to foundation (if available)

### Step 5: Manage Tableau
- Create empty columns by moving Kings
- Uncover face-down cards
- Build long sequences to free up cards
- Plan moves ahead

### Step 6: Win Condition
- All 52 cards in foundation piles = You win!
- No more moves available = Game over

## Strategy Tips

### General Strategy
1. **Expose face-down cards first** - Priority #1
2. **Don't rush to foundation** - Keep cards in tableau for building
3. **Empty columns are valuable** - Use for Kings only
4. **Plan ahead** - Think 2-3 moves ahead
5. **Aces and 2s to foundation** - Safe to move immediately

### Advanced Tips
1. **Keep color balance** - Don't block yourself with same colors
2. **Build evenly** - Don't build one suit too high
3. **Use undo wisely** - Learn from mistakes
4. **Cycle stock carefully** - Remember what's coming
5. **Kings in empty columns** - Choose wisely which King to place

### Common Mistakes
1. **Moving cards to foundation too early** - May need them for building
2. **Filling empty columns with wrong King** - Blocks future moves
3. **Not planning ahead** - Random moves lead to dead ends
4. **Ignoring face-down cards** - Always prioritize uncovering
5. **Giving up too early** - Many games are winnable with patience

## Scoring (Optional)

### Standard Scoring
- **Waste to Tableau:** 5 points
- **Waste to Foundation:** 10 points
- **Tableau to Foundation:** 10 points
- **Turn over tableau card:** 5 points
- **Foundation to Tableau:** -15 points (penalty)
- **Recycle waste:** -100 points (Draw 3 mode)

### Time Bonus
- **Timed mode:** Bonus points for faster completion
- **Standard time:** 10 minutes
- **Bonus:** Points decrease over time

### Vegas Scoring
- **Buy-in:** -52 points
- **Each card to foundation:** +5 points
- **Win:** +52 points (net 0)
- **Goal:** Maximize profit over multiple games

## Implementation Details

### Planned Features
- 🔜 Classic Klondike layout
- 🔜 Draw 1 and Draw 3 modes
- 🔜 Drag and drop interface
- 🔜 Auto-move to foundation (double-click)
- 🔜 Undo/Redo moves
- 🔜 Hint system
- 🔜 Timer and scoring
- 🔜 Statistics (games played, won, win rate)
- 🔜 Daily challenges
- 🔜 Themes and card backs

### API Endpoints
```
GET https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=28  # Tableau
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=24  # Stock
```

### Technical Implementation
```dart
class SolitaireGame {
  final String deckId;
  final List<List<CardModel>> tableau; // 7 columns
  final List<List<CardModel>> foundation; // 4 piles
  final List<CardModel> stock;
  final List<CardModel> waste;
  final int moves;
  final int score;
  final Duration elapsed;
  final SolitaireDrawMode drawMode; // draw1 or draw3
}

class CardModel {
  final String code;
  final String suit;
  final String value;
  final bool isFaceUp;
  final bool isInFoundation;
  final int tableauColumn;
  final int foundationPile;
}

enum SolitaireDrawMode { draw1, draw3 }
```

### Algorithms Needed
1. **Valid Move Detection:** Check if move is legal
2. **Auto-Complete:** Detect when game is won
3. **Hint System:** Suggest best next move
4. **Undo/Redo:** Track move history
5. **Win Detection:** Check if game is solvable

## Variations

### Draw 1 vs Draw 3
- **Draw 1:** Easier, draw one card at a time from stock
- **Draw 3:** Harder, draw three cards at a time, only top card playable

### Thoughtful Solitaire
- All cards face up from the start
- Pure strategy, no luck
- Much harder to win

### Vegas Solitaire
- Draw 3 mode only
- Limited stock cycles (usually 3)
- Scoring based on money won/lost

## Statistics

### Win Rate
- **Draw 1:** ~30% winnable with perfect play
- **Draw 3:** ~10% winnable with perfect play
- **Average player:** Much lower win rate

### Average Game Time
- **Quick game:** 3-5 minutes
- **Average game:** 8-12 minutes
- **Difficult game:** 15-20 minutes

## Glossary

- **Tableau:** Seven columns of cards in the main playing area
- **Foundation:** Four piles where you build suits from Ace to King
- **Stock:** Face-down pile of undealt cards
- **Waste:** Face-up pile of cards drawn from stock
- **Build:** Place cards in descending order
- **Sequence:** Multiple cards that can be moved together
- **Face-down card:** Card showing back design
- **Face-up card:** Card showing rank and suit
- **Empty column:** Tableau column with no cards (only Kings allowed)

## References

- [Klondike Solitaire Rules - Wikipedia](https://en.wikipedia.org/wiki/Klondike_(solitaire))
- [Solitaire Strategy Guide](https://www.solitairecentral.com/articles/KlondikeStrategyGuide.html)
- [Card Game Rules](https://bicyclecards.com/how-to-play/solitaire/)

