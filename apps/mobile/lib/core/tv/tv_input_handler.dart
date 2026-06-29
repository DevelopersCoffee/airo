import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TV input key types for D-pad and remote control
///
/// Supports Android TV, Fire TV, and other TV platforms.
enum TvInputKey {
  up,
  down,
  left,
  right,
  select, // OK/Enter button
  back,
  playPause,
  fastForward,
  rewind,
  menu,
  // Fire TV specific
  voiceSearch, // Fire TV voice button
  channelUp,
  channelDown,
  home,
}

/// Result of handling a TV input
enum TvInputResult {
  /// Input was handled, stop propagation
  handled,

  /// Input was not handled, allow propagation
  notHandled,
}

/// Callback for TV input events
typedef TvInputCallback = TvInputResult Function(TvInputKey key);

/// TV Input Handler for D-pad and remote control navigation
///
/// Wraps a widget to intercept D-pad and media button inputs.
/// Converts low-level keyboard events to semantic TV input keys.
///
/// Usage:
/// ```dart
/// TvInputHandler(
///   onInput: (key) {
///     if (key == TvInputKey.select) {
///       _activateCurrentItem();
///       return TvInputResult.handled;
///     }
///     return TvInputResult.notHandled;
///   },
///   child: MyTvWidget(),
/// )
/// ```
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
    // Only handle key down events
    if (event is! KeyDownEvent) return;

    final tvKey = mapLogicalKeyToTvInput(event.logicalKey);
    if (tvKey != null) {
      onInput?.call(tvKey);
    }
  }

  /// Map Flutter logical keys to TV input keys
  ///
  /// Supports Android TV and Fire TV remote mappings.
  /// Fire TV Voice button maps to [TvInputKey.voiceSearch].
  static TvInputKey? mapLogicalKeyToTvInput(LogicalKeyboardKey key) {
    // D-pad navigation (Android TV, Fire TV)
    if (key == LogicalKeyboardKey.arrowUp) return TvInputKey.up;
    if (key == LogicalKeyboardKey.arrowDown) return TvInputKey.down;
    if (key == LogicalKeyboardKey.arrowLeft) return TvInputKey.left;
    if (key == LogicalKeyboardKey.arrowRight) return TvInputKey.right;

    // Selection (OK button on remotes)
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      return TvInputKey.select;
    }

    // Back/Escape (common on all TV remotes)
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      return TvInputKey.back;
    }

    // Media controls (Android TV, Fire TV)
    if (key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      return TvInputKey.playPause;
    }
    if (key == LogicalKeyboardKey.mediaFastForward) {
      return TvInputKey.fastForward;
    }
    if (key == LogicalKeyboardKey.mediaRewind) return TvInputKey.rewind;

    // Channel controls (Fire TV, some Android TV remotes)
    if (key == LogicalKeyboardKey.channelUp ||
        key == LogicalKeyboardKey.pageUp) {
      return TvInputKey.channelUp;
    }
    if (key == LogicalKeyboardKey.channelDown ||
        key == LogicalKeyboardKey.pageDown) {
      return TvInputKey.channelDown;
    }

    // Menu (Android TV)
    if (key == LogicalKeyboardKey.contextMenu || key == LogicalKeyboardKey.f1) {
      return TvInputKey.menu;
    }

    // Fire TV Voice Search (Alexa button)
    // On Fire TV, voice button typically sends search key
    if (key == LogicalKeyboardKey.browserSearch ||
        key == LogicalKeyboardKey.launchAssistant) {
      return TvInputKey.voiceSearch;
    }

    // Home button
    if (key == LogicalKeyboardKey.browserHome ||
        key == LogicalKeyboardKey.home) {
      return TvInputKey.home;
    }

    return null;
  }

  /// Check if a logical key is a TV navigation key
  static bool isTvNavigationKey(LogicalKeyboardKey key) {
    return mapLogicalKeyToTvInput(key) != null;
  }
}

/// Extension to provide TV input utilities
extension TvInputKeyExtension on TvInputKey {
  /// Whether this key triggers focus movement
  bool get isNavigationKey =>
      this == TvInputKey.up ||
      this == TvInputKey.down ||
      this == TvInputKey.left ||
      this == TvInputKey.right;

  /// Whether this key triggers playback control
  bool get isMediaKey =>
      this == TvInputKey.playPause ||
      this == TvInputKey.fastForward ||
      this == TvInputKey.rewind;

  /// Whether this key triggers channel change
  bool get isChannelKey =>
      this == TvInputKey.channelUp || this == TvInputKey.channelDown;

  /// Whether this key is Fire TV specific
  bool get isFireTvKey =>
      this == TvInputKey.voiceSearch ||
      this == TvInputKey.channelUp ||
      this == TvInputKey.channelDown;
}
