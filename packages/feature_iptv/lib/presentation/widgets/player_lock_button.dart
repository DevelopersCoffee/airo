import 'package:flutter/material.dart';

/// Freezes/unfreezes the player's touch controls (tap-to-seek, gestures,
/// overlay buttons) so the screen can go in a pocket without triggering
/// accidental input. Standard lock/unlock icon toggle, always visible so a
/// locked player can still be unlocked.
class PlayerLockButton extends StatelessWidget {
  const PlayerLockButton({
    super.key,
    required this.locked,
    required this.onToggle,
  });

  final bool locked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        locked ? Icons.lock_outline : Icons.lock_open,
        color: Colors.white,
        size: 20,
      ),
      tooltip: locked ? 'Unlock controls' : 'Lock controls',
      onPressed: onToggle,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}
