import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../iptv/presentation/screens/iptv_screen.dart';
import '../../../music/presentation/screens/music_screen.dart';

enum MediaSection { music, tv }

class MediaHubScreen extends StatelessWidget {
  const MediaHubScreen({super.key, required this.section});

  final MediaSection section;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _MediaModeBar(section: section),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: switch (section) {
              MediaSection.music => const MusicScreenBody(
                key: ValueKey('media-music'),
              ),
              MediaSection.tv => const IPTVScreenBody(
                key: ValueKey('media-tv'),
              ),
            },
          ),
        ),
      ],
    );
  }
}

class _MediaModeBar extends StatelessWidget {
  const _MediaModeBar({required this.section});

  final MediaSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: colorScheme.outlineVariant),
          right: BorderSide(color: colorScheme.outlineVariant),
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _MediaModeButton(
                label: 'Music',
                icon: Icons.music_note,
                selected: section == MediaSection.music,
                onTap: () => context.go('/media/music'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MediaModeButton(
                label: 'TV',
                icon: Icons.live_tv,
                selected: section == MediaSection.tv,
                onTap: () => context.go('/media/tv'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaModeButton extends StatelessWidget {
  const _MediaModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.12)
          : colorScheme.surface.withValues(alpha: 0.18),
      child: InkWell(
        onTap: selected ? null : onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label.toUpperCase(), style: theme.textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}
