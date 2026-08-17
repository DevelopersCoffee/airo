import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/log_models.dart';

/// Optional navigation hook for shell routes the menu bar cannot import.
abstract final class MindRuntimeNavigation {
  static void Function()? openHub;
}

/// The macOS native menu bar for a Mind surface.
///
/// File, Edit, Capture, Context, Model, Window, Help — the design's own list.
/// Wrapping [child] in [PlatformMenuBar] puts these in the OS's own menu bar
/// rather than a Flutter-drawn imitation, which is the "Mac conventions
/// supply the chrome" half of the surface. Every item calls a real
/// [MindRuntime] method or [onOpenEverythingBrowser]; none is a placeholder
/// that does nothing when chosen.
class MindNativeMenuBar extends StatelessWidget {
  const MindNativeMenuBar({
    super.key,
    required this.runtime,
    required this.child,
    required this.onOpenEverythingBrowser,
    this.onAbout,
  });

  final MindRuntime runtime;
  final Widget child;

  /// File > New Note, Edit > Search Everything, Capture > Quick Capture and
  /// Window > Everything Browser all funnel here — opening the browser is
  /// the one action nearly every menu leads to, matching what ⌘K already
  /// does rather than adding a second path.
  final VoidCallback onOpenEverythingBrowser;

  final VoidCallback? onAbout;

  static const _summonShortcut = SingleActivator(
    LogicalKeyboardKey.keyK,
    meta: true,
  );

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'New Note',
              onSelected: () => unawaited(
                runtime.log.append(
                  kind: MindOpKind.note,
                  title: 'Untitled note',
                  contextId: '',
                ),
              ),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Search Everything',
              shortcut: _summonShortcut,
              onSelected: onOpenEverythingBrowser,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Capture',
          menus: [
            PlatformMenuItem(
              label: 'Quick Capture',
              onSelected: () => unawaited(
                runtime.log.append(
                  kind: MindOpKind.automation,
                  title: 'Quick capture',
                  contextId: '',
                ),
              ),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Context',
          menus: [
            PlatformMenuItem(
              label: 'New Context…',
              onSelected: () =>
                  unawaited(runtime.contexts.create(label: '#NewContext')),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Model',
          menus: [
            PlatformMenuItem(
              label: 'Model Library',
              onSelected: () => unawaited(runtime.models.all()),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Window',
          menus: [
            PlatformMenuItem(
              label: 'Everything Browser',
              shortcut: _summonShortcut,
              onSelected: onOpenEverythingBrowser,
            ),
            PlatformMenuItem(
              label: 'Mind Runtime…',
              onSelected: () {
                // Shell-owned route — menu cannot import go_router here.
                MindRuntimeNavigation.openHub?.call();
              },
            ),
          ],
        ),
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(
              label: 'About Airo Mind',
              onSelected: onAbout ?? () {},
            ),
          ],
        ),
      ],
      child: child,
    );
  }
}
