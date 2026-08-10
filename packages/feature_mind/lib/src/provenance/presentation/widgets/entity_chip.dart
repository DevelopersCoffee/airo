import 'package:flutter/material.dart';

import '../../../widgets/mind_palette.dart';
import '../../domain/models/extracted_entity.dart';

/// A tappable citation chip for one extracted entity.
///
/// Same tap-target floor as `MindContextChip` (rule R02, extended by issue
/// #1463 to citation chips): a person points at "Dr. Rao" and lands on the
/// op(s) that produced it, exactly as an Agent Chat citation (#1458) points
/// back at its grounding op.
class EntityChip extends StatelessWidget {
  const EntityChip({super.key, required this.entity, required this.onTap});

  final ExtractedEntity entity;
  final VoidCallback onTap;

  /// The phone surface's stated floor. A 24 px chip is one a person misses.
  static const double minimumTarget = 48;

  static const Map<EntityType, String> _typeLabels = {
    EntityType.person: 'person',
    EntityType.date: 'date',
    EntityType.term: 'term',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${entity.text}, ${_typeLabels[entity.type]}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minimumTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: MindPalette.ink.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entity.text,
                  style: const TextStyle(fontSize: 12, color: MindPalette.ink),
                ),
                Text(
                  _typeLabels[entity.type]!,
                  style: TextStyle(
                    fontSize: 10,
                    color: MindPalette.ink.withValues(alpha: 0.55),
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
