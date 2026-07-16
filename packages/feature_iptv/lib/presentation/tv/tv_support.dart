import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class FocusMemoryEntry {
  final String screenId;
  final String? itemId;
  final int? index;

  const FocusMemoryEntry({required this.screenId, this.itemId, this.index});
}

class TvFocusManager extends ChangeNotifier {
  final Map<String, FocusMemoryEntry> _focusMemory = {};

  void saveFocusState({required String screenId, String? itemId, int? index}) {
    _focusMemory[screenId] = FocusMemoryEntry(
      screenId: screenId,
      itemId: itemId,
      index: index,
    );
  }

  FocusMemoryEntry? getFocusState(String screenId) {
    return _focusMemory[screenId];
  }
}

final tvFocusManagerProvider = ChangeNotifierProvider<TvFocusManager>((ref) {
  return TvFocusManager();
});

final isTvModeProvider = Provider.family<bool, BuildContext>((ref, context) {
  return MediaQuery.sizeOf(context).width >= 960;
});

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
    final tvKey = mapLogicalKeyToTvInput(event.logicalKey);
    if (tvKey != null) {
      onInput?.call(tvKey);
    }
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
    if (key == LogicalKeyboardKey.contextMenu) return TvInputKey.menu;
    if (key == LogicalKeyboardKey.mediaTrackNext) return TvInputKey.channelUp;
    if (key == LogicalKeyboardKey.mediaTrackPrevious) {
      return TvInputKey.channelDown;
    }
    if (key == LogicalKeyboardKey.home) return TvInputKey.home;
    if (key == LogicalKeyboardKey.launchApplication1) {
      return TvInputKey.voiceSearch;
    }
    return null;
  }
}

extension TvInputKeyChecks on TvInputKey {
  bool get isChannelKey =>
      this == TvInputKey.channelUp || this == TvInputKey.channelDown;
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
    this.safeZone = EdgeInsets.zero,
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
  );
}

final tvDimensionsProvider = Provider.family<TvUiDimensions, BuildContext>(
  (ref, context) => MediaQuery.sizeOf(context).width >= 960
      ? TvUiDimensions.tv()
      : TvUiDimensions.mobile(),
);

class TvFocusConstants {
  static const double focusBorderRadius = 8;
  static const Duration focusAnimationDuration = Duration(milliseconds: 120);
}

class TvFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onSelect;
  final VoidCallback? onFocus;
  final bool enabled;
  final double borderRadius;

  const TvFocusable({
    super.key,
    required this.child,
    this.onSelect,
    this.onFocus,
    this.enabled = true,
    this.borderRadius = TvFocusConstants.focusBorderRadius,
    bool autofocus = false,
    bool showScaleEffect = true,
    bool showBorderEffect = true,
    bool showGlowEffect = true,
    String? semanticLabel,
    String? semanticHint,
    bool? semanticButton,
    bool announceFocus = false,
    VoidCallback? onUnfocus,
    Color? focusColor,
  });

  @override
  State<TvFocusable> createState() => _TvFocusableState();
}

class _TvFocusableState extends State<TvFocusable> {
  late final FocusNode _focusNode;
  final ValueNotifier<bool> _focused = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (hasFocus != _focused.value) {
      _focused.value = hasFocus;
      if (hasFocus) widget.onFocus?.call();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _focused.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onSelect?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: InkWell(
        onTap: widget.enabled ? widget.onSelect : null,
        // ValueListenableBuilder rebuilds only the decoration,
        // not the entire widget subtree, on focus changes.
        child: ValueListenableBuilder<bool>(
          valueListenable: _focused,
          builder: (context, isFocused, child) {
            return AnimatedContainer(
              duration: TvFocusConstants.focusAnimationDuration,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.borderRadius),
                border: isFocused
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 3,
                      )
                    : null,
              ),
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
