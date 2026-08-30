import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/log_models.dart';
import 'mind_desktop_chrome.dart';

/// Optional navigation hook for shell routes the menu bar cannot import.
///
/// The Mind shell assigns these from [GoRouter] so File/Model/Help items
/// reach chat, models, and profile without `feature_mind` depending on `app`.
abstract final class MindRuntimeNavigation {
  static void Function()? openHub;
  static void Function()? openIntelligence;
  static void Function()? openNewChat;
  static void Function()? openSettings;
  static void Function()? openModelLibrary;
  static void Function()? openDeviceCapabilities;
  static void Function()? openPromptLab;
  static void Function()? openLogs;
}

/// The macOS native menu bar for a Mind surface.
///
/// App lifecycle, File, Edit, Capture, Model, View, Window, Help. Wrapping
/// [child] in [PlatformMenuBar] puts these in the OS menu bar rather than a
/// Flutter-drawn imitation. Standard items use [PlatformProvidedMenuItem] so
/// Hide/Quit/Full Screen/Minimize are the real AppKit actions. Custom items
/// call [MindRuntime], [MindRuntimeNavigation], or [MindChatMenuActions].
class MindNativeMenuBar extends StatelessWidget {
  const MindNativeMenuBar({
    super.key,
    required this.runtime,
    required this.child,
    required this.onOpenEverythingBrowser,
    this.onAbout,
    this.onToggleTheme,
    this.onToggleSidebar,
  });

  final MindRuntime runtime;
  final Widget child;
  final VoidCallback onOpenEverythingBrowser;
  final VoidCallback? onAbout;
  final void Function(ThemeMode mode)? onToggleTheme;
  final VoidCallback? onToggleSidebar;

  static const _newChatShortcut = SingleActivator(
    LogicalKeyboardKey.keyN,
    meta: true,
  );
  static const _settingsShortcut = SingleActivator(
    LogicalKeyboardKey.comma,
    meta: true,
  );
  static const _summonShortcut = SingleActivator(
    LogicalKeyboardKey.keyK,
    meta: true,
  );
  static const _sidebarShortcut = SingleActivator(
    LogicalKeyboardKey.keyB,
    meta: true,
  );
  static const _exportShortcut = SingleActivator(
    LogicalKeyboardKey.keyE,
    meta: true,
    shift: true,
  );

  /// Flattened menu actions for tests. Recurses submenus and groups.
  static Map<String, VoidCallback?> collectActions(PlatformMenuBar bar) {
    final labels = <String, VoidCallback?>{};
    void collect(List<PlatformMenuItem> items) {
      for (final item in items) {
        if (item is PlatformMenu) {
          collect(item.menus);
          continue;
        }
        if (item is PlatformMenuItemGroup) {
          collect(item.members);
          continue;
        }
        if (item.label.isEmpty) continue;
        labels[item.label] = item.onSelected;
      }
    }

    collect(bar.menus);
    return labels;
  }

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'Airo Mind',
          menus: [
            PlatformMenuItemGroup(
              members: [
                ..._macosProvided(PlatformProvidedMenuItemType.about),
                PlatformMenuItem(
                  label: 'Settings…',
                  shortcut: _settingsShortcut,
                  onSelected: MindRuntimeNavigation.openSettings,
                ),
              ],
            ),
            ..._menuGroup([
              ..._macosProvided(PlatformProvidedMenuItemType.hide),
              ..._macosProvided(
                PlatformProvidedMenuItemType.hideOtherApplications,
              ),
              ..._macosProvided(
                PlatformProvidedMenuItemType.showAllApplications,
              ),
            ]),
            ..._menuGroup([
              ..._macosProvided(PlatformProvidedMenuItemType.quit),
            ]),
          ],
        ),
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'New Chat',
                  shortcut: _newChatShortcut,
                  onSelected: () {
                    MindChatMenuActions.newChat?.call();
                    MindRuntimeNavigation.openNewChat?.call();
                  },
                ),
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
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Export Chat',
                  shortcut: _exportShortcut,
                  onSelected: MindChatMenuActions.exportChat,
                ),
              ],
            ),
            // No "Close Window" item. Nothing here can close the window:
            // there is no window-management plugin and its callback was
            // never assigned, so it rendered permanently greyed out with a
            // Cmd-W that did nothing. Implementing it needs more care than a
            // channel call, too — this is a single-window app whose
            // `MainFlutterWindow` has no reopen path, so a real close would
            // leave a running process with no window and no way back. The
            // window's own close button still works.
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Undo',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                  ),
                  onSelected: () => _invokeFocused(
                    const UndoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: 'Redo',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyZ,
                    meta: true,
                    shift: true,
                  ),
                  onSelected: () => _invokeFocused(
                    const RedoTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Cut',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyX,
                    meta: true,
                  ),
                  onSelected: () => _invokeFocused(
                    const CopySelectionTextIntent.cut(
                      SelectionChangedCause.keyboard,
                    ),
                  ),
                ),
                PlatformMenuItem(
                  label: 'Copy',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyC,
                    meta: true,
                  ),
                  onSelected: () =>
                      _invokeFocused(CopySelectionTextIntent.copy),
                ),
                PlatformMenuItem(
                  label: 'Paste',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyV,
                    meta: true,
                  ),
                  onSelected: () => _invokeFocused(
                    const PasteTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
                PlatformMenuItem(
                  label: 'Select All',
                  shortcut: const SingleActivator(
                    LogicalKeyboardKey.keyA,
                    meta: true,
                  ),
                  onSelected: () => _invokeFocused(
                    const SelectAllTextIntent(SelectionChangedCause.keyboard),
                  ),
                ),
              ],
            ),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Clear Chat',
                  onSelected: MindChatMenuActions.clearChat,
                ),
                PlatformMenuItem(
                  label: 'Search Everything',
                  shortcut: _summonShortcut,
                  onSelected: onOpenEverythingBrowser,
                ),
              ],
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
            PlatformMenuItem(
              label: 'New Context…',
              onSelected: () =>
                  unawaited(runtime.contexts.create(label: '#NewContext')),
            ),
          ],
        ),
        PlatformMenu(
          label: 'Intelligence',
          menus: [
            PlatformMenuItem(
              label: 'Intelligence',
              onSelected: () => MindRuntimeNavigation.openIntelligence?.call(),
            ),
            PlatformMenuItem(
              label: 'Model Library',
              onSelected: () {
                MindRuntimeNavigation.openModelLibrary?.call();
                unawaited(runtime.models.all());
              },
            ),
            PlatformMenuItem(
              label: 'Device & Acceleration…',
              onSelected: MindRuntimeNavigation.openDeviceCapabilities,
            ),
            PlatformMenuItem(
              label: 'Prompt Lab / Persona',
              onSelected: MindRuntimeNavigation.openPromptLab,
            ),
          ],
        ),
        PlatformMenu(
          label: 'View',
          menus: [
            PlatformMenuItem(
              label: 'Toggle Sidebar',
              shortcut: _sidebarShortcut,
              onSelected: onToggleSidebar,
            ),
            PlatformMenu(
              label: 'Appearance',
              menus: [
                PlatformMenuItem(
                  label: 'Light',
                  onSelected: () => onToggleTheme?.call(ThemeMode.light),
                ),
                PlatformMenuItem(
                  label: 'Dark',
                  onSelected: () => onToggleTheme?.call(ThemeMode.dark),
                ),
                PlatformMenuItem(
                  label: 'System',
                  onSelected: () => onToggleTheme?.call(ThemeMode.system),
                ),
              ],
            ),
            ..._macosProvided(PlatformProvidedMenuItemType.toggleFullScreen),
          ],
        ),
        PlatformMenu(
          label: 'Window',
          menus: [
            ..._menuGroup([
              ..._macosProvided(PlatformProvidedMenuItemType.minimizeWindow),
              ..._macosProvided(PlatformProvidedMenuItemType.zoomWindow),
            ]),
            PlatformMenuItemGroup(
              members: [
                PlatformMenuItem(
                  label: 'Everything Browser',
                  shortcut: _summonShortcut,
                  onSelected: onOpenEverythingBrowser,
                ),
                PlatformMenuItem(
                  label: 'Mind Runtime…',
                  onSelected: () => MindRuntimeNavigation.openHub?.call(),
                ),
              ],
            ),
            ..._macosProvided(
              PlatformProvidedMenuItemType.arrangeWindowsInFront,
            ),
          ],
        ),
        PlatformMenu(
          label: 'Help',
          menus: [
            PlatformMenuItem(label: 'About Airo Mind', onSelected: onAbout),
            PlatformMenuItem(
              label: 'Documentation',
              onSelected: MindRuntimeNavigation.openPromptLab,
            ),
            PlatformMenuItem(
              label: 'Troubleshooting / Logs',
              onSelected: MindRuntimeNavigation.openLogs,
            ),
          ],
        ),
      ],
      child: child,
    );
  }

  static void _invokeFocused<T extends Intent>(T intent) {
    final focused = WidgetsBinding.instance.focusManager.primaryFocus?.context;
    if (focused == null) return;
    Actions.maybeInvoke<T>(focused, intent);
  }
}

List<PlatformMenuItem> _macosProvided(PlatformProvidedMenuItemType type) {
  if (!PlatformProvidedMenuItem.hasMenu(type)) {
    return const [];
  }
  return [PlatformProvidedMenuItem(type: type)];
}

List<PlatformMenuItem> _menuGroup(List<PlatformMenuItem> members) {
  if (members.isEmpty) return const [];
  return [PlatformMenuItemGroup(members: members)];
}
