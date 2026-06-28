import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../providers/navigation_provider.dart';
import '../../shared/widgets/app_icon_placeholder.dart';

enum _CompactShellMenuAction { profile, logout }

class AppShellChrome extends StatelessWidget implements PreferredSizeWidget {
  const AppShellChrome({
    super.key,
    required this.title,
    required this.user,
    required this.config,
    required this.onHomeTap,
    required this.onNotificationsTap,
    required this.onProfileTap,
    required this.onLogoutTap,
  });

  final Widget title;
  final User? user;
  final AppNavigationChromeConfig config;
  final VoidCallback onHomeTap;
  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final VoidCallback onLogoutTap;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < config.compactWidthBreakpoint;

    return AppBar(
      leading: InkWell(
        key: const ValueKey('app_shell_home_button'),
        onTap: onHomeTap,
        borderRadius: BorderRadius.circular(20),
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: AppIconPlaceholder(size: 32, errorBuilder: _homeIconFallback),
        ),
      ),
      title: title,
      centerTitle: true,
      actions: [..._buildActions(context, isCompact), const SizedBox(width: 8)],
    );
  }

  List<Widget> _buildActions(BuildContext context, bool isCompact) {
    final actions = <Widget>[];
    final hasNotifications = config.enabledActions.contains(
      AppShellAction.notifications,
    );
    final hasProfileMenu = config.enabledActions.contains(
      AppShellAction.profileMenu,
    );

    if (hasNotifications) {
      actions.add(
        IconButton(
          key: const ValueKey('app_shell_notifications_button'),
          tooltip: 'Notifications',
          onPressed: onNotificationsTap,
          icon: const Icon(Icons.notifications_outlined),
        ),
      );
    }

    if (!hasProfileMenu) {
      return actions;
    }

    if (isCompact) {
      actions.add(_buildCompactOverflowMenu(context));
      return actions;
    }

    actions.add(_buildProfileMenu(context));
    return actions;
  }

  Widget _buildCompactOverflowMenu(BuildContext context) {
    return PopupMenuButton<_CompactShellMenuAction>(
      key: const ValueKey('app_shell_overflow_button'),
      tooltip: 'More actions',
      onSelected: (value) {
        switch (value) {
          case _CompactShellMenuAction.profile:
            onProfileTap();
          case _CompactShellMenuAction.logout:
            onLogoutTap();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<_CompactShellMenuAction>(
          value: _CompactShellMenuAction.profile,
          child: Row(
            children: [Icon(Icons.person), SizedBox(width: 8), Text('Profile')],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<_CompactShellMenuAction>(
          value: _CompactShellMenuAction.logout,
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert),
    );
  }

  Widget _buildProfileMenu(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopupMenuButton<String>(
      key: const ValueKey('app_shell_profile_menu_button'),
      tooltip: 'Profile',
      onSelected: (value) {
        if (value == 'logout') {
          onLogoutTap();
          return;
        }
        if (value == 'profile') {
          onProfileTap();
        }
      },
      icon: CircleAvatar(
        radius: 16,
        backgroundColor: colorScheme.primaryContainer,
        child: user?.photoUrl != null
            ? ClipOval(
                child: Image.network(
                  user!.photoUrl!,
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _AvatarInitials(initials: _getInitials(user!.username)),
                ),
              )
            : _AvatarInitials(initials: _getInitials(user?.username ?? 'U')),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person),
              const SizedBox(width: 8),
              Text(user?.username ?? 'Guest'),
              if (user?.isGoogleUser == true) ...[
                const SizedBox(width: 4),
                Icon(Icons.verified, size: 16, color: colorScheme.primary),
              ],
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, color: Colors.red),
              SizedBox(width: 8),
              Text('Logout', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }
}

class _AvatarInitials extends StatelessWidget {
  const _AvatarInitials({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }
}

String _getInitials(String name) {
  final parts = name
      .trim()
      .split(' ')
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'U';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

Widget _homeIconFallback(
  BuildContext context,
  Object error,
  StackTrace? stackTrace,
) {
  return const Icon(Icons.home);
}
