# Rummy (Gin Rummy)

## Overview

Gin Rummy is a two-player card game where players try to form sets and runs of cards to minimize the value of unmatched cards in their hand.

**Status:** 🔜 Coming Soon  
**Players:** 2  
**Difficulty:** Medium  
**Deck:** 1 standard 52-card deck

## Objective

Be the first to reach 100 points by forming melds (sets and runs) and minimizing deadwood (unmatched cards).

## Rules

### Card Values
- **Ace:** 1 point
- **Number cards (2-10):** Face value
- **Face cards (J, Q, K):** 10 points each

### Melds
**Set:** Three or four cards of the same rank
- Example: 7♠ 7♥ 7♦

**Run:** Three or more consecutive cards of the same suit
- Example: 4♣ 5♣ 6♣ 7♣

### Deadwood
- Cards that are not part of any meld
- Total value of deadwood determines scoring

### Game Structure
1. **Deal:** Each player receives 10 cards
2. **Draw:** Take a card from stock or discard pile
3. **Discard:** Discard one card to discard pile
4. **Knock:** End round when deadwood is 10 or less
5. **Gin:** End round with zero deadwood (bonus points)
6. **Undercut:** Opponent has less deadwood than knocker

## How to Play

### Step 1: Deal
- Dealer gives each player 10 cards, one at a time
- Next card is placed face up to start discard pile
- Remaining cards form the stock pile
- Non-dealer goes first

### Step 2: Draw Phase
On your turn, you must draw one card from either:
- **Stock pile** (face down) - Take the top card
- **Discard pile** (face up) - Take the top card

### Step 3: Meld Formation
- Arrange your cards into sets and runs
- Try to minimize deadwood value
- Plan ahead for future melds

### Step 4: Discard Phase
- After drawing, discard one card face up
- Cannot discard the card you just drew from discard pile
- Turn passes to opponent

### Step 5: Knocking
When your deadwood is 10 or less, you can knock:
1. Draw a card
2. Arrange melds
3. Discard one card face down
4. Reveal your hand
5. Opponent reveals their hand
6. Opponent can "lay off" cards on your melds
7. Calculate scores

### Step 6: Going Gin
If you have zero deadwood:
1. Declare "Gin!"
2. Reveal your hand
3. Opponent cannot lay off cards
4. You get bonus points

### Step 7: Scoring
**If you knock:**
- Your deadwood - Opponent's deadwood = Your points
- If opponent has less deadwood, they "undercut" you and get 25 bonus points

**If you go Gin:**
- Opponent's deadwood + 25 bonus points = Your points

**Game ends when a player reaches 100 points**

## Strategy Tips

### Early Game
1. **Draw from stock** - Don't reveal your strategy
2. **Keep flexible cards** - Cards that can form multiple melds
3. **Watch discards** - Remember what opponent discards
4. **Build runs** - Easier to extend than sets

### Mid Game
1. **Form melds quickly** - Reduce deadwood
2. **Discard high cards** - Minimize potential loss
3. **Track opponent's picks** - Guess their melds
4. **Keep low deadwood** - Prepare to knock

### Late Game
1. **Knock when safe** - Don't wait too long
2. **Go for Gin** - If close to zero deadwood
3. **Defensive discards** - Don't help opponent
4. **Calculate odds** - Know remaining cards

### Advanced Tips
1. **Card counting** - Track which cards have been played
2. **Baiting** - Discard cards to mislead opponent
3. **Blocking** - Hold cards opponent needs
4. **Timing** - Know when to knock vs. go for Gin

## Implementation Details

### Planned Features
- 🔜 Two-player gameplay
- 🔜 AI opponent with adjustable difficulty
- 🔜 Meld detection and validation
- 🔜 Deadwood calculation
- 🔜 Knock and Gin mechanics
- 🔜 Lay-off system
- 🔜 Score tracking to 100 points
- 🔜 Game statistics
- 🔜 Hint system for beginners
- 🔜 Undo last move

### API Endpoints
```
GET https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=10  # Deal to player 1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=10  # Deal to player 2
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=1   # Start discard pile
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=1   # Draw from stock
```

### Technical Implementation
```dart
class RummyGame {
  final String deckId;
  final RummyPlayer player;
  final RummyPlayer opponent;
  final List<CardModel> discardPile;
  final int stockCount;
  final RummyGamePhase phase;
  final int playerScore;
  final int opponentScore;
}

class RummyPlayer {
  final List<CardModel> hand;
  final List<Meld> melds;
  final int deadwood;
  final bool hasKnocked;
  final bool hasGin;
}

class Meld {
  final MeldType type; // set or run
  final List<CardModel> cards;
}

enum MeldType { set, run }
```

### Algorithms Needed
1. **Meld Detection:** Find all valid sets and runs
2. **Optimal Melding:** Minimize deadwood value
3. **Lay-off Detection:** Find cards that fit opponent's melds
4. **AI Strategy:** Decision making for draw/discard/knock

## Glossary

- **Meld:** A set or run of cards
- **Set:** Three or four cards of the same rank
- **Run:** Three or more consecutive cards of the same suit
- **Deadwood:** Unmatched cards not in any meld
- **Knock:** End the round with 10 or less deadwood
- **Gin:** End the round with zero deadwood
- **Lay off:** Add cards to opponent's melds after knock
- **Undercut:** Having less deadwood than the knocker
- **Stock:** Face-down draw pile
- **Discard pile:** Face-up pile of discarded cards

## Scoring Examples

### Example 1: Successful Knock
**Your hand:**
- Melds: 7♠ 7♥ 7♦ and 4♣ 5♣ 6♣
- Deadwood: 2♥ 3♦ (5 points)

**Opponent's hand:**
- Melds: K♠ K♥ K♦
- Deadwood: 9♠ 8♥ 4♦ (21 points)

**Score:** 21 - 5 = 16 points for you

### Example 2: Undercut
**Your hand (knocked):**
- Melds: 5♠ 5♥ 5♦
- Deadwood: 9♣ (9 points)

**Opponent's hand:**
- Melds: A♠ 2♠ 3♠ and J♥ J♦ J♣
- Deadwood: 4♥ (4 points)

**Score:** 9 - 4 + 25 = 30 points for opponent (undercut bonus)

### Example 3: Gin
**Your hand:**
- Melds: 8♠ 8♥ 8♦ and 2♣ 3♣ 4♣ 5♣
- Deadwood: 0 points (Gin!)

**Opponent's hand:**
- Deadwood: 18 points

**Score:** 18 + 25 = 43 points for you

## References

- [Gin Rummy Rules - Wikipedia](https://en.wikipedia.org/wiki/Gin_rummy)
- [Gin Rummy Strategy Guide](https://www.pagat.com/rummy/ginrummy.html)
- [Card Game Rules](https://www.bicyclecards.com/how-to-play/gin-rummy/)

