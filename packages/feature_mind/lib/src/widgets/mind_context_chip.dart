import 'package:flutter/material.dart';

import '../runtime/models/context_models.dart';
import 'mind_palette.dart';

/// Rule R02. A hypergraph tag, everywhere it appears, always tappable.
///
/// [onTap] is required rather than nullable. A decorative tag is the failure
/// this rule exists to prevent, and an optional callback is how decorative
/// tags get written.
class MindContextChip extends StatelessWidget {
  const MindContextChip({
    super.key,
    required this.context,
    required this.onTap,
    this.isSelected = false,
  });

  final MindContext context;
  final VoidCallback onTap;
  final bool isSelected;

  /// The phone surface's stated floor. A 24 px chip is one a person misses.
  static const double minimumTarget = 48;

  static const Color _selected = MindPalette.local;
  static const Color _unselected = MindPalette.ink;

  @override
  Widget build(BuildContext buildContext) {
    final colour = isSelected ? _selected : _unselected;

    return Semantics(
      button: true,
      label: '${context.label}, ${context.itemCount} items',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minimumTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected
                    ? _selected
                    : _unselected.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flexible + ellipsis rather than a bare Text: a chip that
                // sits in a narrow column (the Everything Browser's three
                // panes, a phone in split view) gets a tight maxWidth from
                // its ambient constraints even though this Row itself only
                // asks for as much as its content needs, and a bare Text
                // overflows the moment the label doesn't fit rather than
                // truncating.
                Flexible(
                  child: Text(
                    context.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: colour),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.itemCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colour.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
