import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/blackjack_notifier.dart';

/// Betting panel for placing bets
class BettingPanel extends ConsumerStatefulWidget {
  final dynamic game;

  const BettingPanel({
    super.key,
    required this.game,
  });

  @override
  ConsumerState<BettingPanel> createState() => _BettingPanelState();
}

class _BettingPanelState extends ConsumerState<BettingPanel> {
  int _selectedBet = 10;

  final List<int> _betOptions = [10, 25, 50, 100, 250, 500];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bet amount display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.monetization_on, color: Colors.amber, size: 24),
              const SizedBox(width: 12),
              Text(
                '\$$_selectedBet',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Bet chips
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _betOptions.map((amount) {
            final isSelected = _selectedBet == amount;
            final canAfford = amount <= widget.game.playerBalance;
            
            return _buildBetChip(
              amount: amount,
              isSelected: isSelected,
              canAfford: canAfford,
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        // Deal button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _selectedBet <= widget.game.playerBalance
                ? () => _placeBet()
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              'DEAL',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBetChip({
    required int amount,
    required bool isSelected,
    required bool canAfford,
  }) {
    return GestureDetector(
      onTap: canAfford ? () => setState(() => _selectedBet = amount) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.amber
              : canAfford
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.amber
                : canAfford
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.2),
            width: 2,
          ),
        ),
        child: Text(
          '\$$amount',
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : canAfford
                    ? Colors.white
                    : Colors.grey,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _placeBet() {
    ref.read(blackjackGameProvider.notifier).placeBet(_selectedBet);
  }
}

