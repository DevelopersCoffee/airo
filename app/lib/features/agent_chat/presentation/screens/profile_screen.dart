import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/google_auth_service.dart';
import '../../../../core/http/http_dog.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/routing/route_names.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';

/// User profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

            // Developer Tools section
            Text(
              'Developer Tools',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),

            // HTTP Status Dogs
            ListTile(
              leading: const Icon(Icons.pets),
              title: const Text('HTTP Status Dogs'),
              subtitle: const Text(
                'View all HTTP status codes with dog images',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const HttpStatusReferenceScreen(),
                  ),
                );
              },
            ),

            // Quote Settings
            ListTile(
              leading: const Icon(Icons.format_quote),
              title: const Text('Quote Settings'),
              subtitle: const Text('Manage daily quotes display'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                _showQuoteSettings(context, ref);
              },
            ),

            // Dictionary Demo
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('Dictionary Demo'),
              subtitle: const SelectableTextWithDictionary(
                'Select any word to look it up in the dictionary',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const DictionaryDemoScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () async {
                  // Sign out from Google if user was signed in with Google
                  final user = AuthService.instance.currentUser;
                  if (user?.isGoogleUser == true) {
                    await GoogleAuthService.instance.signOut();
                  }
                  await AuthService.instance.logout();
                  if (context.mounted) {
                    context.go(RouteNames.login);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuoteSettings(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.format_quote),
            SizedBox(width: 8),
            Text('Quote Settings'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, child) {
                final preferences = ref.watch(quotePreferencesProvider);
                return SwitchListTile(
                  title: const Text('Show Daily Quotes'),
                  subtitle: const Text(
                    'Display personalized quotes on screens',
                  ),
                  value: preferences.showQuotes,
                  onChanged: (value) {
                    ref
                        .read(quotePreferencesProvider.notifier)
                        .setShowQuotes(value);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final preferences = ref.watch(quotePreferencesProvider);
                return DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Quote Source',
                    border: OutlineInputBorder(),
                  ),
                  value: preferences.quoteSource,
                  items: const [
                    DropdownMenuItem(
                      value: 'fake',
                      child: Text('Inspirational Quotes'),
                    ),
                    DropdownMenuItem(
                      value: 'zenquotes',
                      child: Text('ZenQuotes API'),
                    ),
                    DropdownMenuItem(
                      value: 'fortuneCookie',
                      child: Text('Fortune Cookies'),
                    ),
                    DropdownMenuItem(
                      value: 'lifeHacks',
                      child: Text('Life Hacks'),
                    ),
                    DropdownMenuItem(
                      value: 'uselessFacts',
                      child: Text('Interesting Facts'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      ref
                          .read(quotePreferencesProvider.notifier)
                          .setQuoteSource(value);
                    }
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
