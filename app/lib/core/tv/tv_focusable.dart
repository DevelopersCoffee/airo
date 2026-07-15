import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'tv_focus_manager.dart';
import 'tv_input_handler.dart';

/// A focusable widget for TV navigation with visual focus indicators
///
/// Wraps a child widget and provides:
/// - D-pad focusability
/// - Visual focus indicator (border, scale, glow)
/// - Select/OK button handling
/// - Automatic focus traversal
///
/// Usage:
/// ```dart
/// TvFocusable(
///   onSelect: () => _playChannel(channel),
///   child: ChannelCard(channel: channel),
/// )
/// ```
class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onFocus;
  final VoidCallback? onUnfocus;
  final bool autofocus;
  final bool enabled;
  final Color? focusColor;
  final double borderRadius;
  final bool showScaleEffect;
  final bool showBorderEffect;
  final bool showGlowEffect;

  /// Semantic label for screen readers (CP-AC-003)
  final String? semanticLabel;

  /// Hint for screen readers describing the action
  final String? semanticHint;

  /// Whether this is a button (default: true if onSelect is provided)
  final bool? semanticButton;

  /// Whether to announce focus changes using SemanticsService
  /// (useful for important UI elements that need explicit announcements)
  final bool announceFocus;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onFocus,
    this.onUnfocus,
    this.autofocus = false,
    this.enabled = true,
    this.focusColor,
    this.borderRadius = TvFocusConstants.focusBorderRadius,
    this.showScaleEffect = true,
    this.showBorderEffect = true,
    this.showGlowEffect = true,
    this.semanticLabel,
    this.semanticHint,
    this.semanticButton,
    this.announceFocus = false,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  final ValueNotifier<bool> _isFocused = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    _animationController = AnimationController(
      duration: TvFocusConstants.focusAnimationDuration,
      vsync: this,
    );

    _scaleAnimation =
        Tween<double>(
          begin: 1.0,
          end: TvFocusConstants.focusScaleFactor,
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _animationController.dispose();
    _isFocused.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus == _isFocused.value) {
      return;
    }
    _isFocused.value = hasFocus;

    if (hasFocus) {
      _animationController.forward();
      widget.onFocus?.call();

      // Announce focus to screen readers if enabled (CP-AC-003)
      if (widget.announceFocus && widget.semanticLabel != null) {
        // ignore: deprecated_member_use
        SemanticsService.announce(widget.semanticLabel!, TextDirection.ltr);
      }
    } else {
      _animationController.reverse();
      widget.onUnfocus?.call();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final tvKey = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    if (tvKey == TvInputKey.select && widget.onSelect != null) {
      _handleSelect();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _handlePointerEnter(PointerEnterEvent _) {
    if (!_focusNode.hasFocus && _focusNode.canRequestFocus) {
      _focusNode.requestFocus();
    }
  }

  void _handleSelect() {
    if (!widget.enabled) return;
    widget.onSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final focusColor =
        widget.focusColor ?? Theme.of(context).colorScheme.primary;

    // Determine if this is a button (has onSelect action)
    final isButton = widget.semanticButton ?? widget.onSelect != null;

    Widget focusableWidget = Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKeyEvent,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isFocused,
        child: widget.child,
        builder: (context, isFocused, child) {
          final decoration = isFocused && widget.showBorderEffect
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(
                    color: focusColor,
                    width: TvFocusConstants.focusBorderWidth,
                  ),
                  boxShadow: widget.showGlowEffect
                      ? [
                          BoxShadow(
                            color: focusColor.withValues(alpha: 0.4),
                            blurRadius: TvFocusConstants.focusGlowSpread * 2,
                            spreadRadius: TvFocusConstants.focusGlowSpread,
                          ),
                        ]
                      : null,
                )
              : const BoxDecoration();

          Widget result = AnimatedBuilder(
            animation: _scaleAnimation,
            child: child,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.showScaleEffect ? _scaleAnimation.value : 1.0,
                child: DecoratedBox(decoration: decoration, child: child),
              );
            },
          );

          if (widget.semanticLabel != null || isButton) {
            result = Semantics(
              label: widget.semanticLabel,
              hint: widget.semanticHint,
              button: isButton,
              enabled: widget.enabled,
              focused: isFocused,
              onTap: widget.onSelect,
              child: result,
            );
          }

          return result;
        },
      ),
    );

    return MouseRegion(
      cursor: widget.onSelect == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: _handlePointerEnter,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onSelect == null ? null : _handleSelect,
        child: focusableWidget,
      ),
    );
  }
}

/// A widget that displays navigation hints for TV UI
///
/// Shows contextual hints like "Press OK to select" or "Use arrows to navigate"
/// based on the current focus state.
class TvNavigationHintWidget extends StatelessWidget {
  final String hint;
  final Color? textColor;
  final double fontSize;
  final bool showIcon;

  const TvNavigationHintWidget({
    super.key,
    required this.hint,
    this.textColor,
    this.fontSize = 12.0,
    this.showIcon = true,
  });

  /// Factory for select hint
  factory TvNavigationHintWidget.select() =>
      const TvNavigationHintWidget(hint: TvNavigationHints.selectHint);

  /// Factory for navigation hint
  factory TvNavigationHintWidget.navigation() =>
      const TvNavigationHintWidget(hint: TvNavigationHints.navigationHint);

  /// Factory for combined hint
  factory TvNavigationHintWidget.combined() =>
      const TvNavigationHintWidget(hint: TvNavigationHints.combinedHint);

  @override
  Widget build(BuildContext context) {
    final color = textColor ?? Colors.white.withValues(alpha: 0.7);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(Icons.info_outline, size: fontSize + 2, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            hint,
            style: TextStyle(color: color, fontSize: fontSize),
          ),
        ],
      ),
    );
  }
}
