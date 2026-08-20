import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Theme for the standalone Mind window. Defaults to dark to match the
/// previous hard-coded [MaterialApp.router] theme.
final mindDesktopThemeModeProvider = StateProvider<ThemeMode>(
  (ref) => ThemeMode.dark,
);

/// Whether the Mind shell's destination bar is visible (View > Toggle Sidebar).
final mindDesktopNavigationVisibleProvider = StateProvider<bool>((ref) => true);

/// Chat-screen actions the native menu bar can invoke without importing the
/// screen. [ChatScreen] attaches while mounted.
abstract final class MindChatMenuActions {
  static Object? _owner;
  static VoidCallback? newChat;
  static VoidCallback? exportChat;
  static VoidCallback? clearChat;

  static void attach(
    Object owner, {
    required VoidCallback newChat,
    required VoidCallback exportChat,
    required VoidCallback clearChat,
  }) {
    _owner = owner;
    MindChatMenuActions.newChat = newChat;
    MindChatMenuActions.exportChat = exportChat;
    MindChatMenuActions.clearChat = clearChat;
  }

  static void detach(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    newChat = null;
    exportChat = null;
    clearChat = null;
  }
}
