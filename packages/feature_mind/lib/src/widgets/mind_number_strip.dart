import 'package:flutter/material.dart';

import 'grouped_number.dart';

/// Rule R04. Ops, peers and vault state, always visible.
///
/// Every cell renders a value even at zero. "0 on LAN" tells a person the mesh
/// is working and alone; an empty slot tells them the app is broken.
class MindNumberStrip extends StatelessWidget {
  const MindNumberStrip({
    super.key,
    required this.opCount,
    required this.peerCount,
    required this.vaultSealed,
  });

  final int opCount;
  final int peerCount;
  final bool vaultSealed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Cell(label: 'LOG', value: '${groupedNumber(opCount)} ops'),
        _Cell(label: 'PEERS', value: '$peerCount on LAN'),
        _Cell(label: 'VAULT', value: vaultSealed ? 'Sealed' : 'Unsealed'),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, letterSpacing: 1.6),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
