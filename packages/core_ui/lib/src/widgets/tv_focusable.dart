import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// Logical TV remote / D-pad input keys, mapped from raw [LogicalKeyboardKey]
/// events by [TvInputHandler.mapLogicalKeyToTvInput].
enum TvInputKey {
  up,
  down,
  left,
  right,
  select,
  back,
  playPause,
  fastForward,
  rewind,
  menu,
  voiceSearch,
  channelUp,
  channelDown,
  home,
}

enum TvInputResult { handled, notHandled }

typedef TvInputCallback = TvInputResult Function(TvInputKey key);

extension TvInputKeyExtension on TvInputKey {
  /// Whether this key triggers focus movement.
  bool get isNavigationKey =>
      this == TvInputKey.up ||
      this == TvInputKey.down ||
      this == TvInputKey.left ||
      this == TvInputKey.right;

  /// Whether this key triggers playback control.
  bool get isMediaKey =>
      this == TvInputKey.playPause ||
      this == TvInputKey.fastForward ||
      this == TvInputKey.rewind;

  bool get isChannelKey =>
      this == TvInputKey.channelUp || this == TvInputKey.channelDown;

  /// Whether this key is Fire TV specific.
  bool get isFireTvKey =>
      this == TvInputKey.voiceSearch ||
      this == TvInputKey.channelUp ||
      this == TvInputKey.channelDown;
}

/// Captures raw key events under [child] and reports them as [TvInputKey]s.
class TvInputHandler extends StatefulWidget {
  final Widget child;
  final TvInputCallback? onInput;
  final bool enabled;

  const TvInputHandler({
    super.key,
    required this.child,
    this.onInput,
    this.enabled = true,
  });

  @override
  State<TvInputHandler> createState() => _TvInputHandlerState();

  static TvInputKey? mapLogicalKeyToTvInput(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return TvInputKey.up;
    if (key == LogicalKeyboardKey.arrowDown) return TvInputKey.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TvInputKey.left;
    if (key == LogicalKeyboardKey.arrowRight) return TvInputKey.right;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return TvInputKey.select;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      return TvInputKey.back;
    }
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      return TvInputKey.playPause;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      return TvInputKey.fastForward;
    }
    if (key == LogicalKeyboardKey.mediaRewind) return TvInputKey.rewind;
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp) {
      return TvInputKey.channelUp;
    }
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown) {
      return TvInputKey.channelDown;
    }
    if (key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f1) {
      return TvInputKey.menu;
    }
    if (key == LogicalKeyboardKey.browserSearch ||
        key == LogicalKeyboardKey.launchAssistant) {
      return TvInputKey.voiceSearch;
    }
    if (key == LogicalKeyboardKey.browserHome ||
        key == LogicalKeyboardKey.home) {
      return TvInputKey.home;
    }
    return null;
  }

  /// Whether a logical key maps to a recognized TV input.
  static bool isTvNavigationKey(LogicalKeyboardKey key) {
    return mapLogicalKeyToTvInput(key) != null;
  }
}

class _TvInputHandlerState extends State<TvInputHandler> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..skipTraversal = true;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: widget.child,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    if (key != null) widget.onInput?.call(key);
  }
}

class TvFocusConstants {
  TvFocusConstants._();

  static const double focusBorderWidth = 3.0;
  static const double focusBorderRadius = 8.0;
  static const Duration focusAnimationDuration = Duration(milliseconds: 200);
  static const double focusScaleFactor = 1.05;
  static const double focusGlowSpread = 4.0;
}

/// A focusable wrapper for TV/D-pad navigation: draws a focus ring + glow,
/// optionally scales on focus, announces semantics, and maps the remote's
/// select/enter key to [onSelect].
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
  final String? semanticLabel;
  final String? semanticHint;
  final bool? semanticButton;
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
  late final FocusNode _focusNode;
  late final AnimationController _animationController;
  late final CurvedAnimation _focusCurve;
  late final Animation<double> _scaleAnimation;
  final ValueNotifier<bool> _isFocused = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
    _animationController = AnimationController(
      duration: TvFocusConstants.focusAnimationDuration,
      vsync: this,
    );
    _focusCurve = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(
      begin: 1,
      end: TvFocusConstants.focusScaleFactor,
    ).animate(_focusCurve);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _focusCurve.dispose();
    _animationController.dispose();
    _isFocused.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus == _isFocused.value) return;
    _isFocused.value = hasFocus;
    if (hasFocus) {
      _animationController.forward();
      widget.onFocus?.call();
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
    final key = TvInputHandler.mapLogicalKeyToTvInput(event.logicalKey);
    if (key == TvInputKey.select && widget.onSelect != null) {
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
    final isButton = widget.semanticButton ?? widget.onSelect != null;

    Widget result = Focus(
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

          Widget focusEffect = AnimatedBuilder(
            animation: _scaleAnimation,
            child: child,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.showScaleEffect ? _scaleAnimation.value : 1,
                child: DecoratedBox(decoration: decoration, child: child),
              );
            },
          );

          if (widget.semanticLabel != null || isButton) {
            focusEffect = Semantics(
              label: widget.semanticLabel,
              hint: widget.semanticHint,
              button: isButton,
              enabled: widget.enabled,
              focused: isFocused,
              onTap: widget.onSelect,
              child: focusEffect,
            );
          }

          return focusEffect;
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
        child: result,
      ),
    );
  }
}
