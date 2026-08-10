import 'package:flutter/material.dart';

import '../runtime/mind_global_shortcut.dart';
import '../runtime/mind_runtime.dart';
import 'mind_everything_browser.dart';

/// Makes ⌘K open the Everything Browser from anywhere under [child].
///
/// "Reachable from every macOS surface, not just this window" is the design's
/// own requirement, so this wraps at the root of a macOS Mind shell rather
/// than living on one screen. [shortcut] defaults to
/// [MindInAppGlobalShortcut]; a test — or #1455, once it lands and needs
/// reconciling — supplies its own [MindGlobalShortcut] instead of a real
/// keyboard listener.
class MindCommandPaletteScope extends StatefulWidget {
  MindCommandPaletteScope({
    super.key,
    required this.runtime,
    required this.child,
    MindGlobalShortcut? shortcut,
  }) : shortcut = shortcut ?? MindInAppGlobalShortcut();

  final MindRuntime runtime;
  final Widget child;
  final MindGlobalShortcut shortcut;

  @override
  State<MindCommandPaletteScope> createState() =>
      MindCommandPaletteScopeState();
}

class MindCommandPaletteScopeState extends State<MindCommandPaletteScope> {
  bool _open = false;

  @override
  void initState() {
    super.initState();
    if (MindEverythingBrowser.isSupportedPlatform) {
      widget.shortcut.register(openPalette);
    }
  }

  @override
  void dispose() {
    widget.shortcut.dispose();
    super.dispose();
  }

  /// Opens the palette. Exposed on the state (reachable via a [GlobalKey] or
  /// `context.findAncestorStateOfType`) so a menu-bar action can trigger the
  /// exact same path as the keyboard shortcut rather than a second one that
  /// could drift from it.
  void openPalette() {
    if (!mounted || _open) return;
    setState(() => _open = true);
  }

  void _closePalette() {
    if (!mounted) return;
    setState(() => _open = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_open)
          Positioned.fill(
            child: Material(
              key: const Key('mind.commandPalette.overlay'),
              color: Colors.black54,
              child: MindEverythingBrowser(
                runtime: widget.runtime,
                onClose: _closePalette,
              ),
            ),
          ),
      ],
    );
  }
}
