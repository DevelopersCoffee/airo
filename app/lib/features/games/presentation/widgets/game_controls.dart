import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/blackjack_notifier.dart';

/// Game controls for hit, stand, double, split
class GameControls extends ConsumerWidget {
  final dynamic game;

  const GameControls({
    super.key,
    required this.game,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Current bet display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'BET:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.monetization_on, color: Colors.amber, size: 18),
              const SizedBox(width: 4),
              Text(
                '\$${game.currentBet}',
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Action buttons
        Row(
          children: [
            // Hit button
            Expanded(
              child: _buildActionButton(
                label: 'HIT',
                icon: Icons.add_circle_outline,
                enabled: game.canHit,
                onPressed: () => ref.read(blackjackGameProvider.notifier).hit(),
                color: Colors.green,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Stand button
            Expanded(
              child: _buildActionButton(
                label: 'STAND',
                icon: Icons.pan_tool,
                enabled: game.canStand,
                onPressed: () => ref.read(blackjackGameProvider.notifier).stand(),
                color: Colors.red,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Secondary actions
        Row(
          children: [
            // Double button
            Expanded(
              child: _buildActionButton(
                label: 'DOUBLE',
                icon: Icons.exposure_plus_2,
                enabled: game.canDouble,
                onPressed: () => ref.read(blackjackGameProvider.notifier).doubleDown(),
                color: Colors.blue,
                isSecondary: true,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Split button
            Expanded(
              child: _buildActionButton(
                label: 'SPLIT',
                icon: Icons.call_split,
                enabled: game.canSplit,
                onPressed: () {
                  // TODO: Implement split functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Split coming soon!')),
                  );
                },
                color: Colors.purple,
                isSecondary: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onPressed,
    required Color color,
    bool isSecondary = false,
  }) {
    return SizedBox(
      height: isSecondary ? 48 : 56,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: isSecondary ? 18 : 20),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isSecondary ? 14 : 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? color : Colors.grey.withValues(alpha: 0.3),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey.withValues(alpha: 0.2),
          disabledForegroundColor: Colors.grey.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: enabled ? 4 : 0,
        ),
      ),
    );
  }
}

