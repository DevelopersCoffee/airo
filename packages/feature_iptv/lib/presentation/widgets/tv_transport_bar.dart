import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Bottom-centered Watch transport overlay: one action row inside a
/// title-safe width cap. Extra actions are dropped from the trailing edge
/// (except More) instead of wrapping to a second line.
class TvTransportBar extends StatelessWidget {
  const TvTransportBar({
    super.key,
    required this.channelName,
    required this.detailLine,
    required this.isLive,
    required this.actions,
    required this.onKeyEvent,
    this.menuHint = 'MENU for more actions',
  });

  static const titleSafeFraction = 0.05;
  static const panelMaxFraction = 0.80;

  final String channelName;
  final String detailLine;
  final bool isLive;
  final List<Widget> actions;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final String menuHint;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final titleSafeWidth = size.width * (1 - 2 * titleSafeFraction);
    final maxPanelWidth = titleSafeWidth * panelMaxFraction;
    final theme = Theme.of(context);
    final titleStyle = AiroTypography.titleMedium.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
    );
    final detailStyle = AiroTypography.labelMedium.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.70),
    );
    final hintStyle = AiroTypography.labelSmall.copyWith(
      color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            key: const ValueKey('iptv-tv-transport-panel'),
            constraints: BoxConstraints(maxWidth: maxPanelWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AiroSpacing.radiusMd),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.72),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AiroSpacing.md,
                  AiroSpacing.lg,
                  AiroSpacing.md,
                  AiroSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        _ChannelMark(name: channelName),
                        const SizedBox(width: AiroSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  if (isLive) ...[
                                    const _LiveChip(),
                                    const SizedBox(width: AiroSpacing.sm),
                                  ],
                                  Flexible(
                                    child: Text(
                                      detailLine,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: detailStyle,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AiroSpacing.xxs),
                              Text(
                                channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: titleStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AiroSpacing.md),
                    Focus(
                      canRequestFocus: false,
                      skipTraversal: true,
                      onKeyEvent: onKeyEvent,
                      child: TvTransportOverflowRow(actions: actions),
                    ),
                    const SizedBox(height: AiroSpacing.sm),
                    Text(menuHint, style: hintStyle),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [actions] in a single [Row]. When they cannot all fit, trailing
/// items before the last (More) are omitted so overflow goes to the More
/// sheet instead of wrapping.
class TvTransportOverflowRow extends StatelessWidget {
  const TvTransportOverflowRow({super.key, required this.actions});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AiroSpacing.sm;
        final itemWidth = AiroSpacing.tvControlSize;
        final maxItems = actions.isEmpty
            ? 0
            : ((constraints.maxWidth + gap) / (itemWidth + gap)).floor().clamp(
                1,
                actions.length,
              );
        final visible = _visibleActions(maxItems);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                height: AiroSpacing.tvControlSize,
                child: visible[index],
              ),
            ],
          ],
        );
      },
    );
  }

  List<Widget> _visibleActions(int maxItems) {
    if (actions.length <= maxItems) return actions;
    if (maxItems <= 1) return [actions.last];
    return [...actions.take(maxItems - 1), actions.last];
  }
}

class TvTransportActionButton extends StatelessWidget {
  const TvTransportActionButton({
    super.key,
    required this.icon,
    this.label,
    this.selected = false,
    this.enabled = true,
  });

  final IconData icon;
  final String? label;
  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final background = selected
        ? theme.colorScheme.primary.withValues(alpha: 0.28)
        : onSurface.withValues(alpha: 0.08);
    final foreground = onSurface.withValues(alpha: enabled ? 1 : 0.38);
    final labelStyle = AiroTypography.labelLarge.copyWith(
      color: foreground,
      fontWeight: FontWeight.w600,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Container(
        height: AiroSpacing.tvControlSize,
        constraints: BoxConstraints(
          minWidth: AiroSpacing.tvMinTarget,
          minHeight: AiroSpacing.tvMinTarget,
          maxHeight: AiroSpacing.tvControlSize,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: label == null ? AiroSpacing.sm : AiroSpacing.md,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AiroSpacing.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: foreground, size: AiroSpacing.lg),
            if (label != null) ...[
              const SizedBox(width: AiroSpacing.sm),
              Text(label!, style: labelStyle),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChannelMark extends StatelessWidget {
  const _ChannelMark({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return Container(
      width: AiroSpacing.tvMinTarget - AiroSpacing.sm,
      height: AiroSpacing.tvMinTarget - AiroSpacing.sm,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AiroSpacing.radiusSm),
      ),
      child: Text(
        letter,
        style: AiroTypography.titleSmall.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AiroSpacing.sm,
        vertical: AiroSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error,
        borderRadius: BorderRadius.circular(AiroSpacing.radiusXs),
      ),
      child: Text(
        'LIVE',
        style: AiroTypography.labelSmall.copyWith(
          color: Theme.of(context).colorScheme.onError,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
