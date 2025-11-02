import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// User profile screen
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 50,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'User Profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'admin@airo.app',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Settings section
            Text('Settings', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            // Bedtime mode toggle
            ListTile(
              title: const Text('Bedtime Mode'),
              subtitle: const Text('Auto-enable at 22:30'),
              trailing: Switch(
                value: false,
                onChanged: (value) {
                  // TODO: Implement bedtime mode toggle
                },
              ),
            ),

            // Audio settings
            ListTile(
              title: const Text('Background Audio'),
              subtitle: const Text('Allow music while using other apps'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // TODO: Implement background audio toggle
                },
              ),
            ),

            // Audio ducking
            ListTile(
              title: const Text('Audio Ducking'),
              subtitle: const Text('Lower music volume during game SFX'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // TODO: Implement audio ducking toggle
                },
              ),
            ),

            const SizedBox(height: 32),

            // Feature flags section
            Text('Features', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            // Agent as default
            ListTile(
              title: const Text('Agent as Default'),
              subtitle: const Text('Start with Agent tab on login'),
              trailing: Switch(
                value: true,
                onChanged: (value) {
                  // TODO: Implement agent default toggle
                },
              ),
            ),

            // Meeting minutes
            ListTile(
              title: const Text('Meeting Minutes'),
              subtitle: const Text('WIP: Voice capture and MoM synthesis'),
              trailing: const Chip(
                label: Text('WIP'),
                backgroundColor: Colors.orange,
              ),
            ),

            const SizedBox(height: 32),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                onPressed: () {
                  // TODO: Implement logout
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logout not yet implemented')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
