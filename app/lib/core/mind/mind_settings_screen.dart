import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/presentation/widgets/app_info_tile.dart';
import '../routing/route_names.dart';

/// Mind-owned settings hub: appearance, on-device AI, capture, and backup.
///
/// The super app's [SettingsHubScreen] is IPTV configuration. This shell
/// does not ship Live TV, so Profile's Settings tile and Airo Mind >
/// Settings… must land here instead of `/models` or [MindUnavailableScreen].
class MindSettingsScreen extends ConsumerWidget {
  const MindSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(assistantHostAdapterProvider);
    final themeMode = ref.watch(mindDesktopThemeModeProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text('Light'),
                  icon: Icon(Icons.light_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  label: Text('Dark'),
                  icon: Icon(Icons.dark_mode_outlined),
                ),
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text('System'),
                  icon: Icon(Icons.brightness_auto_outlined),
                ),
              ],
              selected: {themeMode},
              onSelectionChanged: (modes) {
                ref.read(mindDesktopThemeModeProvider.notifier).state =
                    modes.first;
              },
            ),
          ),
          const SizedBox(height: 24),
          host.aiPreferencesSection(),
          const SizedBox(height: 24),
          Text('Meeting recordings', style: theme.textTheme.titleMedium),
          const AudioRetentionSettingsTile(),
          const SpeechLanguageSettingsTile(),
          const IndicGenerationSettingsTile(),
          const IndicSpeechBackendSettingsTile(),
          const SizedBox(height: 24),
          Text('This device', style: theme.textTheme.titleMedium),
          ListTile(
            leading: const Icon(Icons.import_export_outlined),
            title: const Text('Backup and restore'),
            subtitle: const Text(
              'Encrypted export and import for local AI setup',
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () =>
                context.push('${RouteNames.settings}/airo-portability'),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Account, quotes, and developer tools'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => context.go(AssistantRouteNames.profile),
          ),
          ListTile(
            leading: const Icon(Icons.memory_outlined),
            title: const Text('Offline models'),
            subtitle: const Text('Download and manage local GGUF weights'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => host.openModelManager(context),
          ),
          const SizedBox(height: 24),
          const AppInfoTile(),
        ],
      ),
    );
  }
}
