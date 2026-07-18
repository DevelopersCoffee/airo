import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:core_ai/core_ai.dart';
import '../../../../core/auth/auth_service.dart';
import '../../../../core/auth/google_auth_service.dart';
import '../../../../core/http/http_dog.dart';
import '../../../../core/dictionary/dictionary.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../shared/widgets/bug_report_dialog.dart';
import '../../../quotes/presentation/widgets/daily_quote_card.dart';
import '../../../settings/application/ai_storage_dashboard.dart';
import '../../../settings/application/ai_preferences_settings.dart';
import '../../../settings/application/ai_model_management.dart';
import '../../../settings/presentation/screens/ai_models_screen.dart';
import '../../../settings/presentation/screens/intelligent_model_manager_screen.dart';

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

            // Settings
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              subtitle: const Text(
                'Appearance, audio, playback, and playlist source',
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => context.push(RouteNames.settings),
            ),

            const SizedBox(height: 24),
            const _AIPreferencesSection(),

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

            // Bug Report
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Report a Bug'),
              subtitle: const Text('Submit bug reports to GitHub'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                BugReportDialog.show(context);
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

class _AIPreferencesSection extends ConsumerWidget {
  const _AIPreferencesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiPreferencesSettingsProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final storageDashboard = ref.watch(aiStorageDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Model Preferences',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('Active Model'),
                subtitle: Text(
                  selectedModel?.name ?? 'Browse or download a local model',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AIModelsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('Intelligent Model Manager'),
                subtitle: const Text('Advanced model management UI'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const IntelligentModelManagerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.alt_route_outlined),
                title: const Text('Routing Strategy'),
                subtitle: Text(
                  _routingStrategyLabel(settings.routingStrategy),
                  key: const Key('ai-routing-strategy-subtitle'),
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<AIRoutingStrategy>(
                    key: const Key('ai-routing-strategy-dropdown'),
                    value: settings.routingStrategy,
                    items: AIRoutingStrategy.values.map((strategy) {
                      return DropdownMenuItem(
                        value: strategy,
                        child: Text(_routingStrategyLabel(strategy)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(routingStrategy: value));
                    },
                  ),
                ),
              ),
              SwitchListTile(
                key: const Key('ai-auto-fallback-switch'),
                secondary: const Icon(Icons.swap_horiz_outlined),
                title: const Text('Enable Auto-Fallback'),
                subtitle: const Text(
                  'Automatically use the backup runtime when the preferred one is unavailable.',
                ),
                value: settings.autoFallback,
                onChanged: (value) {
                  ref
                      .read(aiPreferencesSettingsProvider.notifier)
                      .update(settings.copyWith(autoFallback: value));
                },
              ),
              ListTile(
                leading: const Icon(Icons.low_priority_outlined),
                title: const Text('Fallback Order'),
                subtitle: Text(_fallbackOrderLabel(settings.routingStrategy)),
              ),
              ExpansionTile(
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Performance'),
                subtitle: Text(
                  '${settings.accelerationPreference.label} • '
                  '${settings.threadCount} threads • '
                  '${settings.contextLength} tokens',
                ),
                children: [
                  _SettingDropdownRow<AIAccelerationPreference>(
                    label: 'GPU Acceleration',
                    value: settings.accelerationPreference,
                    items: AIAccelerationPreference.values,
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(
                            settings.copyWith(accelerationPreference: value),
                          );
                    },
                  ),
                  _SettingDropdownRow<int>(
                    label: 'Thread Count',
                    value: settings.threadCount,
                    items: const [1, 2, 4, 6, 8],
                    itemLabel: (value) => '$value',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(threadCount: value));
                    },
                  ),
                  _SettingDropdownRow<int>(
                    label: 'Context Length',
                    value: settings.contextLength,
                    items: const [1024, 2048, 4096, 8192],
                    itemLabel: (value) => '$value tokens',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(contextLength: value));
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Storage'),
                subtitle: Text(
                  storageDashboard.when(
                    data: (summary) =>
                        '${_formatBytes(summary.totalUsedBytes)} used',
                    loading: () => 'Checking storage usage',
                    error: (_, _) => 'Storage usage unavailable',
                  ),
                ),
                children: [
                  ...storageDashboard.maybeWhen(
                    data: (summary) => summary.categories.map(
                      (category) => ListTile(
                        dense: true,
                        title: Text(category.label),
                        trailing: Text(
                          category.available
                              ? _formatBytes(category.bytes)
                              : 'Unavailable',
                        ),
                      ),
                    ),
                    orElse: () => const <Widget>[],
                  ),
                  _SettingDropdownRow<AIDownloadLocationPreference>(
                    label: 'Download Location',
                    value: settings.downloadLocation,
                    items: AIDownloadLocationPreference.values,
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(downloadLocation: value));
                    },
                  ),
                  ListTile(
                    title: const Text('Clear Model Cache'),
                    subtitle: const Text(
                      'Remove orphaned partial files and refresh storage usage.',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final removed = await ref
                            .read(aiPreferencesSettingsProvider.notifier)
                            .clearModelCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                removed == 0
                                    ? 'No cached model files needed cleanup.'
                                    : 'Cleared $removed cached model file(s).',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Advanced'),
                subtitle: Text(
                  '${settings.memoryBudgetPercent}% memory budget • '
                  '${settings.debugLogging ? 'Debug logging on' : 'Debug logging off'}',
                ),
                children: [
                  _SettingDropdownRow<int>(
                    label: 'Memory Budget',
                    value: settings.memoryBudgetPercent,
                    items: const [40, 50, 60, 70, 80],
                    itemLabel: (value) => '$value%',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(
                            settings.copyWith(memoryBudgetPercent: value),
                          );
                    },
                  ),
                  SwitchListTile(
                    key: const Key('ai-debug-logging-switch'),
                    title: const Text('Debug Logging'),
                    subtitle: const Text(
                      'Keep local runtime diagnostics available for troubleshooting.',
                    ),
                    value: settings.debugLogging,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(debugLogging: value));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text(
            'Use the model manager to browse downloads, set an active local model, and inspect device-specific readiness.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingDropdownRow<T> extends StatelessWidget {
  const _SettingDropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

String _routingStrategyLabel(AIRoutingStrategy strategy) {
  return switch (strategy) {
    AIRoutingStrategy.onDeviceOnly => 'On-device only',
    AIRoutingStrategy.cloudOnly => 'Cloud only',
    AIRoutingStrategy.onDevicePreferred => 'On-device preferred',
    AIRoutingStrategy.cloudPreferred => 'Cloud preferred',
    AIRoutingStrategy.offlinePreferred => 'Offline preferred',
    AIRoutingStrategy.specificModel => 'Specific model',
    AIRoutingStrategy.userChoice => 'User choice',
  };
}

String _fallbackOrderLabel(AIRoutingStrategy strategy) {
  return switch (strategy) {
    AIRoutingStrategy.onDeviceOnly => 'On-device only',
    AIRoutingStrategy.cloudOnly => 'Cloud only',
    AIRoutingStrategy.onDevicePreferred => 'On-device first, then cloud',
    AIRoutingStrategy.cloudPreferred => 'Cloud first, then on-device',
    AIRoutingStrategy.offlinePreferred => 'Offline runtimes first, then cloud',
    AIRoutingStrategy.specificModel => 'Specific runtime first, then backup',
    AIRoutingStrategy.userChoice => 'User-selected runtime, then fallback',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
