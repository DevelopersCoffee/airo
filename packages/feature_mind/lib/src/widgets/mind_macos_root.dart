import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../agent_chat/application/assistant_model_preferences.dart';
import '../assistant/consent/mind_runtime_provider.dart';
import '../library_loader.dart';
import 'mind_command_palette_scope.dart';
import 'mind_desktop_chrome.dart';
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
  void initState() {
    super.initState();
    MindRuntimeNavigation.openLogs ??= _openLogs;
    ensureMindNativeExitGuard();
  }

  @override
  Widget build(BuildContext context) {
    if (!_useMacChrome) return widget.child;

    final runtime = ref.watch(mindRuntimeProvider);
    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: MindCommandPaletteScope(
        key: _paletteKey,
        runtime: runtime,
        child: MindNativeMenuBar(
          runtime: runtime,
          onOpenEverythingBrowser: () =>
              _paletteKey.currentState?.openPalette(),
          onAbout: _showAbout,
          onToggleTheme: (mode) {
            ref.read(mindDesktopThemeModeProvider.notifier).state = mode;
          },
          onToggleSidebar: () {
            final visible = ref.read(mindDesktopNavigationVisibleProvider);
            ref.read(mindDesktopNavigationVisibleProvider.notifier).state =
                !visible;
          },
          child: widget.child,
        ),
      ),
    );
  }

  void _showAbout() {
    final modelId = ref.read(selectedAssistantModelIdProvider);
    showAboutDialog(
      context: context,
      applicationName: 'Airo Mind',
      applicationLegalese:
          'On-device assistant. Chat inference is llama.cpp GGUF '
          '(Metal on Apple Silicon). Unsloth Python/CUDA is not used.',
      children: [
        const SizedBox(height: 12),
        Text(
          modelId == null
              ? 'No chat model selected. Open Model Manager to download GGUF weights.'
              : 'Active chat model: $modelId',
        ),
      ],
    );
  }

  Future<void> _openLogs() async {
    try {
      final support = await getApplicationSupportDirectory();
      final logs = Directory('${support.path}/logs');
      final target = logs.existsSync() ? logs.path : support.path;
      await Process.run('open', [target]);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('Could not open the logs folder.')),
      );
    }
  }
}
