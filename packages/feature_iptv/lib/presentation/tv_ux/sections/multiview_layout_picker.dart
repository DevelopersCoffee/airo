import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

/// Eight mosaic tiles matching the Cast MultiView layout library.
class MultiviewLayoutPicker extends StatelessWidget {
  const MultiviewLayoutPicker({
    super.key,
    required this.selected,
    required this.capacity,
    required this.onSelected,
  });

  final MultiviewLayoutKind? selected;
  final int capacity;
  final ValueChanged<MultiviewLayoutKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const ValueKey('multiview-layout-picker'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final kind in MultiviewLayoutKind.values)
          _LayoutChoice(
            kind: kind,
            selected: selected == kind,
            enabled: kind.tileCount <= capacity,
            onSelected: onSelected,
          ),
      ],
    );
  }
}

class _LayoutChoice extends StatelessWidget {
  const _LayoutChoice({
    required this.kind,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final MultiviewLayoutKind kind;
  final bool selected;
  final bool enabled;
  final ValueChanged<MultiviewLayoutKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final border = selected ? colors.primary : colors.outlineVariant;
    return TvFocusable(
      semanticLabel: kind.label,
      onSelect: enabled ? () => onSelected(kind) : null,
      child: InkWell(
        key: ValueKey('multiview-layout-pick-${kind.wireName}'),
        onTap: enabled ? () => onSelected(kind) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.38,
          child: SizedBox(
            width: 72,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: border, width: selected ? 2 : 1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: CustomPaint(
                      size: const Size(56, 40),
                      painter: MultiviewLayoutMosaicPainter(
                        kind: kind,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kind.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension MultiviewLayoutKindLabel on MultiviewLayoutKind {
  String get label => switch (this) {
    MultiviewLayoutKind.single => '1 pane',
    MultiviewLayoutKind.splitHorizontal => '2 split',
    MultiviewLayoutKind.splitVertical => '2 stack',
    MultiviewLayoutKind.tripleTop => '1 over 2',
    MultiviewLayoutKind.tripleBottom => '2 over 1',
    MultiviewLayoutKind.tripleLeft => '1 + 2',
    MultiviewLayoutKind.quad => '2×2',
    MultiviewLayoutKind.spotlight => '1 + 3',
  };
}

class MultiviewLayoutMosaicPainter extends CustomPainter {
  const MultiviewLayoutMosaicPainter({required this.kind, required this.color});

  final MultiviewLayoutKind kind;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color.withValues(alpha: 0.72);
    final gap = 1.5;
    for (final cell in _cells(kind)) {
      final rect = Rect.fromLTWH(
        cell.left * size.width + gap,
        cell.top * size.height + gap,
        cell.width * size.width - gap * 2,
        cell.height * size.height - gap * 2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(1.5)),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MultiviewLayoutMosaicPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

List<Rect> _cells(MultiviewLayoutKind kind) {
  return switch (kind) {
    MultiviewLayoutKind.single => [const Rect.fromLTWH(0, 0, 1, 1)],
    MultiviewLayoutKind.splitHorizontal => [
      const Rect.fromLTWH(0, 0, 0.5, 1),
      const Rect.fromLTWH(0.5, 0, 0.5, 1),
    ],
    MultiviewLayoutKind.splitVertical => [
      const Rect.fromLTWH(0, 0, 1, 0.5),
      const Rect.fromLTWH(0, 0.5, 1, 0.5),
    ],
    MultiviewLayoutKind.tripleTop => [
      const Rect.fromLTWH(0, 0, 1, 0.5),
      const Rect.fromLTWH(0, 0.5, 0.5, 0.5),
      const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
    ],
    MultiviewLayoutKind.tripleBottom => [
      const Rect.fromLTWH(0, 0, 0.5, 0.5),
      const Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      const Rect.fromLTWH(0, 0.5, 1, 0.5),
    ],
    MultiviewLayoutKind.tripleLeft => [
      const Rect.fromLTWH(0, 0, 0.58, 1),
      const Rect.fromLTWH(0.58, 0, 0.42, 0.5),
      const Rect.fromLTWH(0.58, 0.5, 0.42, 0.5),
    ],
    MultiviewLayoutKind.quad => [
      const Rect.fromLTWH(0, 0, 0.5, 0.5),
      const Rect.fromLTWH(0.5, 0, 0.5, 0.5),
      const Rect.fromLTWH(0, 0.5, 0.5, 0.5),
      const Rect.fromLTWH(0.5, 0.5, 0.5, 0.5),
    ],
    MultiviewLayoutKind.spotlight => [
      const Rect.fromLTWH(0, 0, 0.62, 1),
      const Rect.fromLTWH(0.62, 0, 0.38, 1 / 3),
      const Rect.fromLTWH(0.62, 1 / 3, 0.38, 1 / 3),
      const Rect.fromLTWH(0.62, 2 / 3, 0.38, 1 / 3),
    ],
  };
}
