import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/blackjack_notifier.dart';
import '../../domain/models/blackjack_model.dart';
import '../../domain/models/game_info.dart';
import '../widgets/playing_card_widget.dart';
import '../widgets/betting_panel.dart';
import '../widgets/game_controls.dart';
import '../widgets/game_rules_dialog_unified.dart';

/// Zen-mode Blackjack screen with immersive experience
class BlackjackScreen extends ConsumerStatefulWidget {
  const BlackjackScreen({super.key});

  @override
  ConsumerState<BlackjackScreen> createState() => _BlackjackScreenState();
}

class _BlackjackScreenState extends ConsumerState<BlackjackScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize fade animation for zen mode
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();

    // Start a new game
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(blackjackGameProvider.notifier).startNewGame();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(blackjackGameProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0F2027),
              const Color(0xFF203A43),
              const Color(0xFF2C5364),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: game == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      // Top bar
                      _buildTopBar(context),

                      // Main game area
                      Expanded(child: _buildGameArea(context, game)),

                      // Bottom controls
                      _buildBottomControls(context, game),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),

          const Spacer(),

          // Title
          const Text(
            'Blackjack',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          // Rules button
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.white70),
            onPressed: () {
              UnifiedGameRulesDialog.show(context, GameRegistry.blackjack);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGameArea(BuildContext context, game) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Dealer section
            _buildDealerSection(context, game),

            const SizedBox(height: 40),

            // Center message
            if (game.message != null) _buildMessageCard(context, game.message!),

            const SizedBox(height: 40),

            // Player section
            _buildPlayerSection(context, game),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDealerSection(BuildContext context, game) {
    final dealerValue = game.dealerHand.isEmpty
        ? 0
        : _calculateHandValue(game.dealerHand, game.dealerCardHidden);

    return Column(
      children: [
        // Dealer label
        Text(
          'DEALER',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 8),

        // Dealer value
        if (game.dealerHand.isNotEmpty)
          Text(
            game.dealerCardHidden ? '?' : dealerValue.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

        const SizedBox(height: 16),

        // Dealer cards
        _buildCardRow(game.dealerHand, hideFirst: game.dealerCardHidden),
      ],
    );
  }

  Widget _buildPlayerSection(BuildContext context, game) {
    final playerValue = game.playerHand.isEmpty
        ? 0
        : _calculateHandValue(game.playerHand, false);

    return Column(
      children: [
        // Player cards
        _buildCardRow(game.playerHand),

        const SizedBox(height: 16),

        // Player value
        if (game.playerHand.isNotEmpty)
          Text(
            playerValue.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),

        const SizedBox(height: 8),

        // Player label
        Text(
          'YOU',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),

        const SizedBox(height: 16),

        // Balance
        _buildBalanceChip(game.playerBalance),
      ],
    );
  }

  Widget _buildCardRow(List cards, {bool hideFirst = false}) {
    if (cards.isEmpty) {
      return const SizedBox(height: 120);
    }

    return SizedBox(
      height: 140,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              cards.length,
              (index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: PlayingCardWidget(
                  card: cards[index],
                  isHidden: hideFirst && index == 0,
                  delay: Duration(milliseconds: index * 200),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBalanceChip(int balance) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.monetization_on, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            '\$$balance',
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(BuildContext context, game) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: game.status == BlackjackGameStatus.betting
          ? BettingPanel(game: game)
          : GameControls(game: game),
    );
  }

  int _calculateHandValue(List cards, bool hideFirst) {
    if (hideFirst && cards.isNotEmpty) {
      // Only show first card value
      return _getCardValue(cards[0]);
    }

    int value = 0;
    int aces = 0;

    for (final card in cards) {
      final cardValue = card.value;
      if (cardValue == 'ACE') {
        aces++;
        value += 11;
      } else if (['JACK', 'QUEEN', 'KING'].contains(cardValue)) {
        value += 10;
      } else {
        value += int.tryParse(cardValue) ?? 0;
      }
    }

    while (value > 21 && aces > 0) {
      value -= 10;
      aces--;
    }

    return value;
  }

  int _getCardValue(dynamic card) {
    final cardValue = card.value;
    if (cardValue == 'ACE') return 11;
    if (['JACK', 'QUEEN', 'KING'].contains(cardValue)) return 10;
    return int.tryParse(cardValue) ?? 0;
  }
}
