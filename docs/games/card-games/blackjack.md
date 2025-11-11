# Blackjack (21)

## Overview

Blackjack, also known as 21, is a classic casino card game where players compete against the dealer to get a hand value as close to 21 as possible without going over.

**Status:** ✅ Available  
**Players:** 1-5  
**Difficulty:** Medium  
**Deck:** 1 standard 52-card deck (6-deck shoe planned for future)

## Objective

Beat the dealer by having a hand value closer to 21 than the dealer's hand, without exceeding 21.

## Rules

1. **Card Values:**
   - Number cards (2-10) are worth their face value
   - Face cards (Jack, Queen, King) are worth 10
   - Aces are worth 1 or 11 (whichever is better for the hand)

2. **Blackjack:** An Ace and a 10-value card on the first two cards is called "Blackjack" and pays 3:2

3. **Bust:** If your hand exceeds 21, you "bust" and lose your bet

4. **Dealer Rules:**
   - Dealer must hit on 16 or less
   - Dealer must stand on 17 or more
   - Dealer's first card is face up, second card is face down (hole card)

5. **Winning:**
   - If you have Blackjack and dealer doesn't, you win 3:2
   - If you beat the dealer without busting, you win 1:1
   - If you tie with the dealer, it's a "push" (bet returned)
   - If dealer busts and you don't, you win 1:1

## How to Play

### Step 1: Place Your Bet
- Choose your bet amount using the betting panel
- Minimum bet: 10 chips
- Maximum bet: 1000 chips
- Tap "Deal" to start the round

### Step 2: Receive Initial Cards
- You receive 2 cards face up
- Dealer receives 2 cards (1 face up, 1 face down)
- If you have Blackjack (21), you win automatically (unless dealer also has Blackjack)

### Step 3: Make Your Decision
You have several options:

**HIT** - Take another card
- Use when your hand is low and you want to get closer to 21
- You can hit multiple times
- Be careful not to bust (exceed 21)

**STAND** - Keep your current hand
- Use when you're satisfied with your hand value
- Dealer will then play their hand

**DOUBLE DOWN** - Double your bet and take exactly one more card
- Only available on your first two cards
- Good strategy when you have 10 or 11
- You must stand after receiving the card

**SPLIT** - Split a pair into two separate hands
- Only available when you have two cards of the same value
- Each hand gets a separate bet equal to your original bet
- You play each hand independently
- Not implemented in current version

### Step 4: Dealer's Turn
- After you stand, dealer reveals their hole card
- Dealer must hit on 16 or less
- Dealer must stand on 17 or more
- Dealer has no choice in their actions

### Step 5: Determine Winner
- If you bust, you lose immediately
- If dealer busts and you didn't, you win
- If neither busts, highest hand wins
- Ties result in a push (bet returned)

## Strategy Tips

### Basic Strategy
1. **Always hit on 11 or less** - You can't bust
2. **Always stand on 17 or more** - Risk of busting is too high
3. **Double down on 10 or 11** - When dealer shows 2-9
4. **Never take insurance** - It's a bad bet in the long run

### When to Hit
- You have 12-16 and dealer shows 7 or higher
- You have soft 17 or less (Ace counted as 11)

### When to Stand
- You have 17 or higher
- You have 12-16 and dealer shows 2-6

### When to Double Down
- You have 10 or 11 and dealer shows 2-9
- You have soft 16-18 and dealer shows 4-6

## Implementation Details

### Technology Stack
- **API:** [Deck of Cards API](https://deckofcardsapi.com/)
- **State Management:** Riverpod with `BlackjackNotifier`
- **UI Framework:** Flutter with custom card widgets
- **Card Images:** Cached network images from Deck of Cards API

### Features
- ✅ Zen-mode immersive UI with gradient background
- ✅ Animated card dealing
- ✅ Real-time hand value calculation
- ✅ Soft/hard Ace handling
- ✅ Betting system with chip balance
- ✅ Hit, Stand, Double Down actions
- ✅ Dealer AI following standard rules
- ✅ Win/loss/push detection
- ✅ Game rules dialog
- 🔜 Split pairs
- 🔜 Insurance
- 🔜 6-deck shoe
- 🔜 Card counting hints
- 🔜 Statistics tracking

### API Endpoints Used
```
GET https://deckofcardsapi.com/api/deck/new/shuffle/?deck_count=1
GET https://deckofcardsapi.com/api/deck/{deck_id}/draw/?count=2
GET https://deckofcardsapi.com/api/deck/{deck_id}/shuffle/
```

### File Structure
```
app/lib/features/games/
├── domain/
│   ├── models/
│   │   ├── card_model.dart          # Card and deck models
│   │   └── blackjack_model.dart     # Game state models
│   └── services/
│       └── deck_of_cards_service.dart # API service
├── application/
│   ├── blackjack_notifier.dart      # State management
│   └── card_asset_manager.dart      # Image preloading
└── presentation/
    ├── screens/
    │   └── blackjack_screen.dart    # Main game UI
    └── widgets/
        ├── playing_card_widget.dart # Card display
        ├── betting_panel.dart       # Betting UI
        └── game_controls.dart       # Hit/Stand buttons
```

## Glossary

- **Blackjack:** A hand with an Ace and a 10-value card (21 in two cards)
- **Bust:** When a hand exceeds 21
- **Hit:** Take another card
- **Stand:** Keep current hand and end turn
- **Double Down:** Double bet and take exactly one more card
- **Split:** Divide a pair into two separate hands
- **Push:** Tie with dealer, bet is returned
- **Soft Hand:** A hand with an Ace counted as 11
- **Hard Hand:** A hand with no Ace or Ace counted as 1
- **Hole Card:** Dealer's face-down card
- **Insurance:** Side bet when dealer shows an Ace (not implemented)

## References

- [Blackjack Rules - Wikipedia](https://en.wikipedia.org/wiki/Blackjack)
- [Basic Strategy - Wizard of Odds](https://wizardofodds.com/games/blackjack/strategy/calculator/)
- [Deck of Cards API Documentation](https://deckofcardsapi.com/)

