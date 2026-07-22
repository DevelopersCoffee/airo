import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import '../../../../core/providers/app_theme_provider.dart';
import 'audio_settings_screen.dart';
import 'playback_settings_screen.dart';

/// Mobile settings hub (CV item 3): the mobile counterpart to
/// [TvSettingsScreen] — a single scrollable list rather than a rail/detail
/// split, since phone screens don't have room for a persistent side rail.
/// Aggregates appearance and links to the
/// dedicated Audio/Playback/Source screens that previously lived inline in
/// `ProfileScreen`.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RadioGroup<AppThemeId>(
            groupValue: ref.watch(appThemeProvider),
            onChanged: (themeId) {
              if (themeId != null) {
                ref.read(appThemeProvider.notifier).setTheme(themeId);
              }
            },
            child: Column(
              children: [
                for (final theme in AppTheme.themes)
                  RadioListTile<AppThemeId>(
                    value: theme.id,
                    title: Text(theme.name),
                    subtitle: Text(theme.description),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          ListTile(
            leading: const Icon(Icons.settings_voice),
            title: const Text('Audio Settings'),
            subtitle: const Text('Configure context-aware audio behavior'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AudioSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.aspect_ratio),
            title: const Text('Playback Settings'),
            subtitle: const Text('Configure video aspect ratio'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PlaybackSettingsScreen(),
                ),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Playlist Source'),
            subtitle: const Text('Add or remove your M3U playlist URL'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showPlaylistSourceSheet(context, ref),
          ),

          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('EPG Guide Source'),
            subtitle: const Text('Add or refresh your XMLTV guide URL'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => showXmltvSourceSheet(context),
          ),
        ],
      ),
    );
  }
}
