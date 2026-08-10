import 'package:flutter/services.dart';

/// Register-a-callback seam for the ⌘K summon shortcut.
///
/// #1455 lands the real OS-level global hotkey (fires even when no Airo
/// window has focus) in a parallel worktree and is not visible from here.
/// This interface is the minimal shape the Everything Browser needs today —
/// something that can be told "call this when the summon key fires" and
/// later stopped. It intentionally says nothing about *how* the key is
/// captured, so #1455's implementation can satisfy it (or replace it wholesale)
/// without the browser changing. Reconcile the two when #1455 lands; until
/// then [MindInAppGlobalShortcut] below covers the in-app case.
abstract interface class MindGlobalShortcut {
  /// Starts listening for the summon key and calls [onTrigger] each time it
  /// fires. Calling this again before [dispose] replaces the previous
  /// callback rather than stacking a second listener.
  void register(VoidCallback onTrigger);

  /// Stops listening. Safe to call more than once.
  void dispose();
}

/// Fires on ⌘K while any part of this Flutter app has focus.
///
/// Not a true OS-level global hotkey — that is #1455's job and needs a
/// platform channel this worktree does not have. This covers the app-focused
/// case via [HardwareKeyboard] rather than a widget's [FocusNode], so the
/// summon key works from whichever Mind surface the person is looking at,
/// not just one screen that happens to hold focus.
class MindInAppGlobalShortcut implements MindGlobalShortcut {
  VoidCallback? _onTrigger;
  bool _listening = false;

  @override
  void register(VoidCallback onTrigger) {
    _onTrigger = onTrigger;
    if (_listening) return;
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _listening = true;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.keyK) {
      return false;
    }
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final metaHeld =
        pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    if (!metaHeld) return false;
    _onTrigger?.call();
    return true;
  }

  @override
  void dispose() {
    if (_listening) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
      _listening = false;
    }
    _onTrigger = null;
  }
}
