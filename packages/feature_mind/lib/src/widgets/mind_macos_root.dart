import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../assistant/consent/mind_runtime_provider.dart';
import 'mind_command_palette_scope.dart';
import 'mind_native_menu_bar.dart';

/// macOS chrome for the standalone Mind shell: native menu bar + ⌘K palette.
///
/// Wraps at the app root so File/Edit/Window actions and the Everything
/// Browser are reachable from every destination (#1461).
class MindMacOsRoot extends ConsumerStatefulWidget {
  const MindMacOsRoot({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MindMacOsRoot> createState() => _MindMacOsRootState();
}

class _MindMacOsRootState extends ConsumerState<MindMacOsRoot> {
  final _paletteKey = GlobalKey<MindCommandPaletteScopeState>();

  bool get _useMacChrome =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (!_useMacChrome) return widget.child;

    final runtime = ref.watch(mindRuntimeProvider);
    return MindCommandPaletteScope(
      key: _paletteKey,
      runtime: runtime,
      child: MindNativeMenuBar(
        runtime: runtime,
        onOpenEverythingBrowser: () =>
            _paletteKey.currentState?.openPalette(),
        child: widget.child,
      ),
    );
  }
}
