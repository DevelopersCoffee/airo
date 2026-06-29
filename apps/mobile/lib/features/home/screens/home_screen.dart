import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/auth/google_auth_service.dart';
import '../widgets/app_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airo Super App'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                // Sign out from Google if user was signed in with Google
                if (AuthService.instance.currentUser?.isGoogleUser == true) {
                  await GoogleAuthService.instance.signOut();
                }
                await AuthService.instance.logout();
                if (context.mounted) {
                  context.go(RouteNames.login);
                }
              }
            },
            itemBuilder: (context) {
              final user = AuthService.instance.currentUser;
              final displayName = user?.email ?? user?.username ?? 'Unknown';
              return [
                PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      if (user?.photoUrl != null)
                        CircleAvatar(
                          radius: 12,
                          backgroundImage: NetworkImage(user!.photoUrl!),
                        )
                      else
                        const Icon(Icons.person),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user?.isGoogleUser == true)
                        const Icon(
                          Icons.verified,
                          size: 16,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'settings',
                  child: Row(
                    children: [
                      Icon(Icons.settings),
                      SizedBox(width: 8),
                      Text('Settings'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Logout', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome to Airo Super App',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose an app to get started',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  AppCard(
                    title: 'Airo',
                    description: 'Main Airo application',
                    icon: Icons.rocket_launch,
                    color: Colors.blue,
                    onTap: () => context.go(RouteNames.airo),
                  ),
                  AppCard(
                    title: 'AiroMoney',
                    description: 'Financial management',
                    icon: Icons.account_balance_wallet,
                    color: Colors.green,
                    onTap: () => context.go(RouteNames.airomoney),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
