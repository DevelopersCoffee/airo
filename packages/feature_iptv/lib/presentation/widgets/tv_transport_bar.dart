import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// Plans which Watch transport actions stay on the capped row.
///
/// More is identified by [moreKey], never “the last child”. Duplicated
/// More-sheet actions (Subtitles) drop before unique ones (Info, Favourite,
/// Audio).
abstract final class TvTransportOverflow {
  static const moreKey = ValueKey<String>('iptv-player-more-button');
  static const playPauseKey = ValueKey<String>('iptv-tv-transport-play-pause');
  static const restartKey = ValueKey<String>('iptv-tv-transport-restart');
  static const audioKey = ValueKey<String>('iptv-tv-transport-audio');
  static const subtitlesKey = ValueKey<String>('iptv-tv-transport-subtitles');
  static const favouriteKey = ValueKey<String>('iptv-tv-transport-favourite');
  static const infoKey = ValueKey<String>('iptv-tv-transport-info');

  static const dropPriority = [
    subtitlesKey,
    infoKey,
    favouriteKey,
    audioKey,
    restartKey,
  ];

  static int maxVisibleCount(double maxWidth, int actionCount) {
    if (actionCount <= 0) return 0;
    final gap = AiroSpacing.sm;
    final itemWidth = AiroSpacing.tvControlSize;
    return ((maxWidth + gap) / (itemWidth + gap)).floor().clamp(1, actionCount);
  }

  static List<int> visibleIndices(List<Key?> keys, int maxItems) {
    if (keys.isEmpty) return const [];
    final moreIndex = keys.indexWhere((key) => key == moreKey);
    if (keys.length <= maxItems) {
      return List<int>.generate(keys.length, (index) => index);
    }
    if (maxItems <= 1) {
      return moreIndex >= 0 ? [moreIndex] : const [0];
    }

    final dropCount = keys.length - maxItems;
    final dropped = <int>{};
    for (final key in dropPriority) {
      if (dropped.length >= dropCount) break;
      final index = keys.indexWhere((candidate) => candidate == key);
      if (index >= 0 && index != moreIndex) dropped.add(index);
    }
    for (var index = keys.length - 1; index >= 0; index--) {
      if (dropped.length >= dropCount) break;
      if (index == moreIndex || keys[index] == playPauseKey) continue;
      dropped.add(index);
    }

    return [
      for (var index = 0; index < keys.length; index++)
        if (!dropped.contains(index)) index,
    ];
  }

  static Set<Key> droppedKeys(List<Key?> keys, int maxItems) {
    final visible = visibleIndices(keys, maxItems).toSet();
    return {
      for (var index = 0; index < keys.length; index++)
        if (!visible.contains(index) && keys[index] != null) keys[index]!,
    };
  }
}

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
    this.onDroppedKeys,
    this.menuHint = '',
  });

  static const titleSafeFraction = 0.05;
  static const panelMaxFraction = 0.80;

  final String channelName;
  final String detailLine;
  final bool isLive;
  final List<Widget> actions;
  final KeyEventResult Function(FocusNode node, KeyEvent event) onKeyEvent;
  final ValueChanged<Set<Key>>? onDroppedKeys;
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

    return SafeArea(
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
                    child: TvTransportOverflowRow(
                      actions: actions,
                      onDroppedKeys: onDroppedKeys,
                    ),
                  ),
                  const SizedBox(height: AiroSpacing.sm),
                  Text(menuHint, style: hintStyle),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays [actions] in a single [Row]. When they cannot all fit, duplicated
/// More-sheet actions drop first, then unique ones. More stays on the row
/// and is found by [TvTransportOverflow.moreKey].
class TvTransportOverflowRow extends StatelessWidget {
  const TvTransportOverflowRow({
    super.key,
    required this.actions,
    this.onDroppedKeys,
  });

  final List<Widget> actions;
  final ValueChanged<Set<Key>>? onDroppedKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final keys = [for (final action in actions) action.key];
        final maxItems = TvTransportOverflow.maxVisibleCount(
          constraints.maxWidth,
          actions.length,
        );
        final visibleIndexes = TvTransportOverflow.visibleIndices(
          keys,
          maxItems,
        );
        final dropped = TvTransportOverflow.droppedKeys(keys, maxItems);
        final onDropped = onDroppedKeys;
        if (onDropped != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onDropped(dropped);
          });
        }
        final gap = AiroSpacing.sm;
        final itemWidth = AiroSpacing.tvControlSize;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < visibleIndexes.length; index++) ...[
              if (index > 0) SizedBox(width: gap),
              SizedBox(
                width: itemWidth,
                height: AiroSpacing.tvControlSize,
                child: actions[visibleIndexes[index]],
              ),
            ],
          ],
        );
      },
    );
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
