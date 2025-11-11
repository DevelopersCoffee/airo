# Texas Hold'em Poker

## Overview

Texas Hold'em is the most popular variant of poker, where players combine their private cards with community cards to make the best five-card poker hand.

**Status:** 🔜 Coming Soon  
**Players:** 2-9  
**Difficulty:** Hard  
**Deck:** 1 standard 52-card deck

## Objective

Win chips by either having the best five-card poker hand at showdown or by making all other players fold.

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
1. **Blinds:** Two players post forced bets (small blind and big blind)
2. **Hole Cards:** Each player receives 2 private cards face down
3. **Betting Rounds:** Four rounds of betting (Pre-flop, Flop, Turn, River)
4. **Community Cards:** Five cards dealt face up in the center
5. **Showdown:** Remaining players reveal hands, best hand wins

## How to Play

### Step 1: Blinds
- Player to dealer's left posts small blind (half minimum bet)
- Next player posts big blind (full minimum bet)
- Blinds rotate clockwise each hand

### Step 2: Hole Cards (Pre-Flop)
- Each player receives 2 private cards
- First betting round begins with player left of big blind
- Players can: **Fold**, **Call** (match big blind), or **Raise**

### Step 3: The Flop
- Dealer burns one card (discards)
- Dealer deals 3 community cards face up
- Second betting round begins with player left of dealer
- Players can: **Check** (if no bet), **Bet**, **Call**, **Raise**, or **Fold**

### Step 4: The Turn
- Dealer burns one card
- Dealer deals 1 community card face up (4th card)
- Third betting round (same as flop)

### Step 5: The River
- Dealer burns one card
- Dealer deals 1 community card face up (5th card)
- Final betting round (same as turn)

### Step 6: Showdown
- Remaining players reveal their hole cards
- Best five-card hand using any combination of 7 cards (2 hole + 5 community) wins
- Winner takes the pot

## Betting Actions

- **Fold:** Discard your hand and forfeit the pot
- **Check:** Pass action to next player (only if no bet has been made)
- **Bet:** Put chips into the pot
- **Call:** Match the current bet
- **Raise:** Increase the current bet
- **All-In:** Bet all remaining chips

## Strategy Tips

### Starting Hands
**Premium Hands (Always Play):**
- Pocket Aces (AA), Kings (KK), Queens (QQ)
- Ace-King suited (AKs)

**Strong Hands (Play in most positions):**
- Jacks (JJ), Tens (TT)
- Ace-King offsuit (AKo), Ace-Queen suited (AQs)

**Marginal Hands (Play in late position):**
- Small pairs (22-99)
- Suited connectors (e.g., 8♠9♠)

### Position Strategy
- **Early Position:** Play only premium hands
- **Middle Position:** Expand range slightly
- **Late Position (Button):** Play wider range, steal blinds
- **Blinds:** Defend against late position raises

### Post-Flop Play
1. **Continuation Bet:** Bet after raising pre-flop
2. **Pot Control:** Check strong hands to keep pot small
3. **Bluffing:** Represent strong hands on scary boards
4. **Value Betting:** Bet strong hands to build pot

## Implementation Details

### Planned Features
- 🔜 2-9 player support
- 🔜 Blind structure (small/big blinds)
- 🔜 Four betting rounds (pre-flop, flop, turn, river)
- 🔜 Hand ranking evaluation
- 🔜 Pot calculation and side pots
- 🔜 AI opponents with different playing styles
- 🔜 Tournament mode
- 🔜 Cash game mode
- 🔜 Hand history
- 🔜 Statistics tracking

### API Endpoints
```
GET https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=2  # Hole cards
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=3  # Flop
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=1  # Turn/River
```

### Technical Challenges
1. **Hand Evaluation:** Implement poker hand ranking algorithm
2. **Pot Management:** Handle main pot and side pots
3. **AI Logic:** Create believable AI opponents
4. **Betting Logic:** Validate bets, raises, and all-ins
5. **Game State:** Track complex game state across rounds

## Glossary

- **Blinds:** Forced bets posted before cards are dealt
- **Hole Cards:** Private cards dealt to each player
- **Community Cards:** Shared cards dealt face up
- **Flop:** First three community cards
- **Turn:** Fourth community card
- **River:** Fifth and final community card
- **Showdown:** Revealing hands to determine winner
- **Pot:** Total chips bet in current hand
- **Button:** Dealer position marker
- **Position:** Where you sit relative to the dealer
- **All-In:** Betting all remaining chips
- **Side Pot:** Separate pot when player is all-in

## References

- [Texas Hold'em Rules - Wikipedia](https://en.wikipedia.org/wiki/Texas_hold_%27em)
- [Poker Hand Rankings](https://www.pokerstars.com/poker/games/rules/hand-rankings/)
- [Starting Hand Charts](https://upswingpoker.com/poker-starting-hands-chart/)

