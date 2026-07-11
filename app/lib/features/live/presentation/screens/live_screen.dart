import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../music/presentation/screens/music_screen.dart';
import "package:feature_iptv/feature_iptv.dart";
import "package:platform_channels/platform_channels.dart";

/// Live mode enum for toggling between Music and TV
enum LiveMode { music, tv }

/// Combined Live screen with toggle between Music and TV modes
/// Reduces bottom navigation from 6 items to 5
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key, required this.mode});

  final LiveMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFullscreen = ref.watch(isFullscreenModeProvider);

    // Use consistent widget structure - always Scaffold, just hide AppBar in fullscreen
    // This prevents widget disposal/recreation when toggling fullscreen
    // No AppBar here - global AppBar is in AppShell
    return Scaffold(
      body: Column(
        children: [
          // Mode toggle at top (only when not fullscreen)
          if (!isFullscreen)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [_LiveModeToggle(mode: mode)],
              ),
            ),
          // Main content
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(opacity: animation, child: child);
              },
              child: mode == LiveMode.music
                  ? const MusicScreenBody(key: ValueKey('music'))
                  : const IPTVScreenBody(key: ValueKey('tv')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mode toggle widget - segmented button for Music/TV
class _LiveModeToggle extends StatelessWidget {
  const _LiveModeToggle({required this.mode});

  final LiveMode mode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToggleButton(
            icon: Icons.music_note_rounded,
            label: 'Music',
            isSelected: mode == LiveMode.music,
            onTap: () => context.go('/live/music'),
          ),
          _ToggleButton(
            icon: Icons.live_tv_rounded,
            label: 'TV',
            isSelected: mode == LiveMode.tv,
            onTap: () => context.go('/live/tv'),
          ),
        ],
      ),
    );
  }
}

/// Individual toggle button
class _ToggleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
