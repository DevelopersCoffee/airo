import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../capture/presentation/audio_retention_settings_tile.dart';
import '../../../capture/presentation/speech_language_settings_tile.dart';
import '../../../capture/presentation/transcription_mode_settings_tile.dart';
import '../../../notebook/presentation/notebook_locale_settings_tile.dart';
import '../../../settings/indic_generation_settings_tile.dart';
import '../../../settings/indic_speech_backend_settings_tile.dart';
import '../../../host/assistant_host_adapter.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';
import '../../../routing/assistant_route_names.dart';

/// User profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(assistantHostAdapterProvider);
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

            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text('Appearance, on-device AI, and capture'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => host.openHostSettings(context),
            ),

            const SizedBox(height: 24),
            host.aiPreferencesSection(),

            const SizedBox(height: 24),
            // #1656 AC5: raw-audio retention is a Settings toggle, not
            // hardcoded.
            Text(
              'Meeting recordings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const AudioRetentionSettingsTile(),
            const SpeechLanguageSettingsTile(),
            const TranscriptionModeSettingsTile(),
            const NotebookLocaleSettingsTile(),
            const IndicGenerationSettingsTile(),
            const IndicSpeechBackendSettingsTile(),

            const SizedBox(height: 32),

            // Feature flags section
            Text('Features', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),

            // Agent entry point
            ListTile(
              leading: const Icon(Icons.psychology_outlined),
              title: const Text('Agent as Default'),
              subtitle: const Text(
                'Open the Mind workspace; startup defaults are controlled by the app shell.',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                context.go(AssistantRouteNames.assistant);
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
              onTap: () => host.openHttpStatusReference(context),
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
              subtitle: host.dictionaryAwareText(
                'Select any word to look it up in the dictionary',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => host.openDictionaryDemo(context),
            ),

            // Bug Report
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report a Bug'),
              subtitle: const Text('Submit bug reports to GitHub'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => host.showBugReportDialog(context),
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
                onPressed: () => host.signOutAndReturnToLogin(context),
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
                  initialValue: preferences.quoteSource,
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
