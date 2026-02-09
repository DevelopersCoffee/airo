import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/media_hub_providers.dart';
import '../../domain/models/media_mode.dart';

/// A segmented control widget for switching between Music and TV modes.
///
/// Features:
/// - Icons with labels for each mode (🎵 Music, 📺 TV)
/// - Strong active indicator with underline and primary color
/// - Smooth 300ms transition animation
/// - Persists state via selectedMediaModeProvider
class MediaModeSwitch extends ConsumerStatefulWidget {
  const MediaModeSwitch({super.key, this.onModeChanged, this.height = 48.0});

  /// Callback when mode changes (optional, state is already managed via provider)
  final void Function(MediaMode)? onModeChanged;

  /// Height of the switch widget
  final double height;

  /// Animation duration for mode transitions
  static const Duration animationDuration = Duration(milliseconds: 300);

  @override
  ConsumerState<MediaModeSwitch> createState() => _MediaModeSwitchState();
}

class _MediaModeSwitchState extends ConsumerState<MediaModeSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: MediaModeSwitch.animationDuration,
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Initialize animation state based on current mode
    final currentMode = ref.read(selectedMediaModeProvider);
    if (currentMode == MediaMode.tv) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onModeSelected(MediaMode mode) {
    final currentMode = ref.read(selectedMediaModeProvider);
    if (currentMode == mode) return;

    // Update provider state
    ref.read(selectedMediaModeProvider.notifier).state = mode;

    // Animate indicator
    if (mode == MediaMode.tv) {
      _controller.forward();
    } else {
      _controller.reverse();
    }

    // Notify callback
    widget.onModeChanged?.call(mode);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedMode = ref.watch(selectedMediaModeProvider);

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / 2;
          return Stack(
            children: [
              // Animated background indicator
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: _slideAnimation.value * segmentWidth,
                    top: 0,
                    bottom: 0,
                    width: segmentWidth,
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.3,
                            ),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Mode buttons
              Row(
                children: [
                  Expanded(
                    child: _ModeButton(
                      mode: MediaMode.music,
                      isSelected: selectedMode == MediaMode.music,
                      onTap: () => _onModeSelected(MediaMode.music),
                    ),
                  ),
                  Expanded(
                    child: _ModeButton(
                      mode: MediaMode.tv,
                      isSelected: selectedMode == MediaMode.tv,
                      onTap: () => _onModeSelected(MediaMode.tv),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  final MediaMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = isSelected
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: MediaModeSwitch.animationDuration,
        curve: Curves.easeInOut,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mode.icon,
              size: 20,
              color: textColor,
              semanticLabel: '${mode.label} mode',
            ),
            const SizedBox(width: 8),
            Text(
              mode.label,
              style: theme.textTheme.titleSmall?.copyWith(
                color: textColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
