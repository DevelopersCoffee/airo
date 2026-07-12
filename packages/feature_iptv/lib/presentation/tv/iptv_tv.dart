import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class TvInputHandler extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return KeyboardListener(
      focusNode: FocusNode()..skipTraversal = true,
      onKeyEvent: _handleKeyEvent,
      child: child,
    );
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = mapLogicalKeyToTvInput(event.logicalKey);
    if (key != null) onInput?.call(key);
  }

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
}

extension TvInputKeyExtension on TvInputKey {
  bool get isChannelKey =>
      this == TvInputKey.channelUp || this == TvInputKey.channelDown;
}

class FocusMemoryEntry {
  final String screenId;
  final String? itemId;
  final int? index;
  final DateTime timestamp;

  FocusMemoryEntry({
    required this.screenId,
    this.itemId,
    this.index,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class TvFocusManager extends ChangeNotifier {
  final Map<String, FocusMemoryEntry> _focusMemory = {};
  final Map<String, FocusNode> _registeredNodes = {};
  String? _currentSectionId;
  String? _currentItemId;

  String? get currentSectionId => _currentSectionId;
  String? get currentItemId => _currentItemId;

  void registerSection(String sectionId, FocusNode node) {
    _registeredNodes[sectionId] = node;
  }

  void unregisterSection(String sectionId) {
    _registeredNodes.remove(sectionId);
  }

  void focusSection(String sectionId) {
    final node = _registeredNodes[sectionId];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      _currentSectionId = sectionId;
      notifyListeners();
    }
  }

  void saveFocusState({required String screenId, String? itemId, int? index}) {
    _focusMemory[screenId] = FocusMemoryEntry(
      screenId: screenId,
      itemId: itemId,
      index: index,
    );
  }

  FocusMemoryEntry? getFocusState(String screenId) => _focusMemory[screenId];

  void clearFocusState(String screenId) {
    _focusMemory.remove(screenId);
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
  late final Animation<double> _scaleAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
    _animationController = AnimationController(
      duration: TvFocusConstants.focusAnimationDuration,
      vsync: this,
    );
    _scaleAnimation =
        Tween<double>(begin: 1, end: TvFocusConstants.focusScaleFactor).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus == _isFocused) return;
    setState(() => _isFocused = hasFocus);
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
      widget.onSelect!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.showScaleEffect ? _scaleAnimation.value : 1,
            child: Container(
              decoration: _isFocused && widget.showBorderEffect
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
                                blurRadius:
                                    TvFocusConstants.focusGlowSpread * 2,
                                spreadRadius: TvFocusConstants.focusGlowSpread,
                              ),
                            ]
                          : null,
                    )
                  : null,
              child: widget.child,
            ),
          );
        },
      ),
    );

    if (widget.semanticLabel != null || isButton) {
      result = Semantics(
        label: widget.semanticLabel,
        hint: widget.semanticHint,
        button: isButton,
        enabled: widget.enabled,
        focused: _isFocused,
        onTap: widget.onSelect,
        child: result,
      );
    }
    return result;
  }
}

class TvUiDimensions {
  final double minTargetSize;
  final double cardPadding;
  final double gridSpacing;
  final double controlButtonSize;
  final double textScaleFactor;
  final double channelCardWidth;
  final double channelCardHeight;
  final double focusBorderWidth;
  final EdgeInsets safeZone;

  const TvUiDimensions._({
    required this.minTargetSize,
    required this.cardPadding,
    required this.gridSpacing,
    required this.controlButtonSize,
    required this.textScaleFactor,
    required this.channelCardWidth,
    required this.channelCardHeight,
    required this.focusBorderWidth,
    required this.safeZone,
  });

  factory TvUiDimensions.tv() => const TvUiDimensions._(
    minTargetSize: 56,
    cardPadding: 16,
    gridSpacing: 24,
    controlButtonSize: 64,
    textScaleFactor: 1.25,
    channelCardWidth: 200,
    channelCardHeight: 150,
    focusBorderWidth: 3,
    safeZone: EdgeInsets.zero,
  );

  factory TvUiDimensions.mobile() => const TvUiDimensions._(
    minTargetSize: 48,
    cardPadding: 12,
    gridSpacing: 16,
    controlButtonSize: 48,
    textScaleFactor: 1,
    channelCardWidth: 140,
    channelCardHeight: 100,
    focusBorderWidth: 2,
    safeZone: EdgeInsets.zero,
  );
}

final tvFocusManagerProvider = ChangeNotifierProvider<TvFocusManager>((ref) {
  return TvFocusManager();
});

final isTvModeProvider = Provider.family<bool, BuildContext>((ref, context) {
  return MediaQuery.maybeOf(context)?.navigationMode ==
      NavigationMode.directional;
});

final tvDimensionsProvider = Provider.family<TvUiDimensions, BuildContext>((
  ref,
  context,
) {
  return ref.watch(isTvModeProvider(context))
      ? TvUiDimensions.tv()
      : TvUiDimensions.mobile();
});
