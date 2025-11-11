# Poker (5-Card Draw)

## Overview

5-Card Draw is the classic poker variant where players are dealt five cards and can exchange some or all of them in an attempt to make the best poker hand.

**Status:** 🔜 Coming Soon  
**Players:** 2-8  
**Difficulty:** Medium  
**Deck:** 1 standard 52-card deck

## Objective

Win chips by having the best five-card poker hand at showdown or by making all other players fold.

## Rules

### Card Rankings (Highest to Lowest)
1. **Royal Flush:** A, K, Q, J, 10 of the same suit
2. **Straight Flush:** Five consecutive cards of the same suit
3. **Four of a Kind:** Four cards of the same rank
4. **Full House:** Three of a kind plus a pair
5. **Flush:** Five cards of the same suit
6. **Straight:** Five consecutive cards of mixed suits
7. **Three of a Kind:** Three cards of the same rank
8. **Two Pair:** Two different pairs
9. **One Pair:** Two cards of the same rank
10. **High Card:** Highest card when no other hand is made

### Game Structure
1. **Ante:** All players put in a small forced bet
2. **Deal:** Each player receives 5 cards face down
3. **First Betting Round:** Players bet based on their initial hand
4. **Draw:** Players can discard and draw new cards
5. **Second Betting Round:** Players bet after the draw
6. **Showdown:** Remaining players reveal hands, best hand wins

## How to Play

### Step 1: Ante
- All players put in the ante (small forced bet)
- This creates the initial pot

### Step 2: Deal
- Each player receives 5 cards face down
- Players look at their cards privately
- Do not show your cards to other players

### Step 3: First Betting Round
- Player to dealer's left starts
- Players can: **Fold**, **Call** (match current bet), or **Raise**
- Betting continues until all active players have matched the highest bet

### Step 4: Draw Phase
- Players who haven't folded can discard 0-5 cards
- Dealer gives replacement cards from the deck
- Common strategy:
  - Keep pairs, three of a kind, or better
  - Draw to straights and flushes
  - Discard weak hands entirely

### Step 5: Second Betting Round
- Same as first betting round
- Player to dealer's left starts
- Players can: **Check**, **Bet**, **Call**, **Raise**, or **Fold**

### Step 6: Showdown
- Remaining players reveal their hands
- Best five-card hand wins the pot
- If tied, pot is split equally

## Strategy Tips

### Starting Hands
**Strong Hands (Bet/Raise):**
- Pairs of Jacks or better
- Three of a kind
- Straights or flushes
- Four to a straight or flush

**Marginal Hands (Call):**
- Small pairs (2s through 10s)
- Four to an inside straight
- High cards (Ace-King, Ace-Queen)

**Weak Hands (Fold):**
- No pair, no draw
- Low cards with no potential

### Drawing Strategy
**With a Pair:**
- Discard 3 cards, keep the pair
- Chance of improving: ~30%

**With Two Pair:**
- Discard 1 card
- Chance of full house: ~8%

**With Three of a Kind:**
- Discard 2 cards
- Chance of four of a kind: ~4%
- Chance of full house: ~9%

**With Four to a Flush:**
- Discard 1 card
- Chance of flush: ~20%

**With Four to a Straight:**
- Discard 1 card
- Open-ended: ~17% chance
- Inside straight: ~8% chance

### Betting Strategy
1. **Bet strong hands** - Build the pot with good hands
2. **Bluff occasionally** - Represent strong hands you don't have
3. **Position matters** - Act last to see what others do
4. **Watch opponents** - Notice their drawing patterns
5. **Pot odds** - Call only if pot odds justify it

## Implementation Details

### Planned Features
- 🔜 2-8 player support
- 🔜 Ante system
- 🔜 Two betting rounds
- 🔜 Card draw mechanism
- 🔜 Hand ranking evaluation
- 🔜 AI opponents with different strategies
- 🔜 Pot calculation
- 🔜 Hand history
- 🔜 Statistics tracking
- 🔜 Tutorial mode

### API Endpoints
```
GET https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=5  # Initial deal
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=N  # Draw phase (N = cards discarded)
```

### Technical Implementation
```dart
class PokerGame {
  final String deckId;
  final List<PokerPlayer> players;
  final int pot;
  final PokerGamePhase phase; // ante, deal, bet1, draw, bet2, showdown
  final int currentBet;
  final int ante;
}

class PokerPlayer {
  final String id;
  final List<CardModel> hand;
  final int chips;
  final bool hasFolded;
  final int currentBet;
}

enum PokerGamePhase {
  ante,
  deal,
  firstBetting,
  draw,
  secondBetting,
  showdown,
}
```

## Glossary

- **Ante:** Small forced bet all players must make
- **Draw:** Exchanging cards for new ones
- **Fold:** Discard hand and forfeit pot
- **Call:** Match the current bet
- **Raise:** Increase the current bet
- **Check:** Pass action without betting (only if no bet made)
- **Showdown:** Revealing hands to determine winner
- **Pot:** Total chips bet in current hand
- **Bluff:** Betting with a weak hand to make others fold
- **Pat Hand:** Keeping all 5 cards without drawing

## Probability Reference

| Hand | Probability | Odds |
|------|-------------|------|
| Royal Flush | 0.00015% | 649,739:1 |
| Straight Flush | 0.0014% | 72,192:1 |
| Four of a Kind | 0.024% | 4,164:1 |
| Full House | 0.14% | 693:1 |
| Flush | 0.20% | 508:1 |
| Straight | 0.39% | 254:1 |
| Three of a Kind | 2.11% | 46:1 |
| Two Pair | 4.75% | 20:1 |
| One Pair | 42.26% | 1.4:1 |
| High Card | 50.12% | 1:1 |

## References

- [5-Card Draw Rules - Wikipedia](https://en.wikipedia.org/wiki/Five-card_draw)
- [Poker Hand Rankings](https://www.pokerstars.com/poker/games/rules/hand-rankings/)
- [Draw Poker Strategy](https://www.cardplayer.com/poker-tools/odds-calculator/draw-poker)

