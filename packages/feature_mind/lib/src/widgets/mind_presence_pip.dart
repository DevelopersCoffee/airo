import 'package:flutter/material.dart';

/// Rule R01. A pip on every Mind screen saying where the work ran.
///
/// Teal means this device. Anything else means it ran somewhere the person
/// also owns, and the label says which. A pip that only ever showed one state
/// would be decoration, and the rule exists because locality is the product's
/// central claim.
class MindPresencePip extends StatelessWidget {
  const MindPresencePip({super.key, required this.isLocal, this.remoteLabel});

  final bool isLocal;

  /// Which device did the work. Falls back to a truthful "ELSEWHERE" rather
  /// than implying locality when the caller does not know.
  final String? remoteLabel;

  static const Color localColour = Color(0xFF7FE8DE);
  static const Color remoteColour = Color(0xFFFFFF89);

  @override
  Widget build(BuildContext context) {
    final colour = isLocal ? localColour : remoteColour;
    final label = isLocal ? 'ON-DEVICE' : (remoteLabel ?? 'ELSEWHERE');

    return Semantics(
      label: isLocal ? 'Work ran on this device' : 'Work ran on $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('mind.presence.dot'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: colour),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: colour, fontSize: 10, letterSpacing: 1.8),
          ),
        ],
      ),
    );
  }
}
