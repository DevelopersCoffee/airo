import 'package:flutter/material.dart';

import '../runtime/models/projection_models.dart';

/// Rule R03. One control for three views of one log.
///
/// Graph, timeline and search are projections, not places. Routing to them
/// separately would teach a person they are three features that happen to
/// share data, which is the opposite of what the runtime is.
///
/// `scripts/check-mind-projection-routes.sh` enforces the other half: no route
/// may target a single projection.
class MindProjectionSwitcher extends StatelessWidget {
  const MindProjectionSwitcher({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ProjectionKind selected;

  /// Reports which projection, never a route. A caller that turns this into a
  /// navigation has broken the rule the widget exists to hold.
  final ValueChanged<ProjectionKind> onChanged;

  static const Map<ProjectionKind, String> _labels = {
    ProjectionKind.graph: 'GRAPH',
    ProjectionKind.timeline: 'TIMELINE',
    ProjectionKind.search: 'SEARCH',
  };

  static const Color _ink = Color(0xFFFFE6CB);
  static const Color _onSelected = Color(0xFF041C1C);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final kind in ProjectionKind.values)
          Expanded(
            child: Semantics(
              button: true,
              selected: kind == selected,
              child: InkWell(
                onTap: () => onChanged(kind),
                child: Container(
                  height: 48,
                  alignment: Alignment.center,
                  color: kind == selected ? _ink : Colors.transparent,
                  child: Text(
                    _labels[kind]!,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: kind == selected
                          ? _onSelected
                          : _ink.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
