import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_context_provider.dart';
import '../../../../core/audio/audio_context_settings.dart';

/// Audio Settings Screen for context-aware audio configuration
class AudioSettingsScreen extends ConsumerWidget {
  const AudioSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch settings for reactive updates
    final settings = ref.watch(audioContextSettingsProvider);
    final settingsNotifier = ref.read(audioContextSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Audio Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Enable/Disable Section
          _buildSectionHeader(context, 'Context-Aware Audio'),
          SwitchListTile(
            title: const Text('Enable Smart Audio'),
            subtitle: const Text(
              'Automatically adjust music when using other features',
            ),
            value: settings.enabled,
            onChanged: (value) => settingsNotifier.setEnabled(value),
          ),
          const Divider(),

          // Ducking Level Section
          _buildSectionHeader(context, 'Volume Ducking'),
          ListTile(
            title: const Text('Ducking Level'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volume when other audio is playing: ${(settings.duckingLevel * 100).toInt()}%',
                ),
                Slider(
                  value: settings.duckingLevel,
                  min: 0.1,
                  max: 0.5,
                  divisions: 8,
                  label: '${(settings.duckingLevel * 100).toInt()}%',
                  onChanged: settings.enabled
                      ? (value) => settingsNotifier.setDuckingLevel(value)
                      : null,
                ),
              ],
            ),
          ),
          const Divider(),

          // Auto Resume Section
          _buildSectionHeader(context, 'Playback Resume'),
          SwitchListTile(
            title: const Text('Auto Resume'),
            subtitle: const Text('Resume music after video or voice ends'),
            value: settingsNotifier.autoResumeEnabled,
            onChanged: (value) => settingsNotifier.setAutoResume(value),
          ),
          const Divider(),

          // Feature Rules Section
          _buildSectionHeader(context, 'Feature Audio Rules'),
          _buildFeatureRuleTile(
            context,
            icon: Icons.videogame_asset,
            title: 'Games',
            subtitle: 'SFX ducks music',
            behavior: FeatureAudioBehavior.duck,
          ),
          _buildFeatureRuleTile(
            context,
            icon: Icons.tv,
            title: 'IPTV',
            subtitle: 'Video pauses music',
            behavior: FeatureAudioBehavior.pause,
          ),
          _buildFeatureRuleTile(
            context,
            icon: Icons.record_voice_over,
            title: 'Voice Output',
            subtitle: 'TTS ducks music',
            behavior: FeatureAudioBehavior.duck,
          ),
          const Divider(),

          // Audio Focus Info
          _buildSectionHeader(context, 'Current Status'),
          _buildCurrentStatusTile(context, ref),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildFeatureRuleTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required FeatureAudioBehavior behavior,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.secondary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Chip(
        label: Text(
          behavior.name.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _getBehaviorColor(behavior),
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Color _getBehaviorColor(FeatureAudioBehavior behavior) {
    switch (behavior) {
      case FeatureAudioBehavior.none:
        return Colors.grey.shade300;
      case FeatureAudioBehavior.duck:
        return Colors.orange.shade100;
      case FeatureAudioBehavior.pause:
        return Colors.red.shade100;
      case FeatureAudioBehavior.coexist:
        return Colors.green.shade100;
    }
  }

  Widget _buildCurrentStatusTile(BuildContext context, WidgetRef ref) {
    final currentFocus = ref.watch(currentAudioFocusProvider);
    final manager = ref.read(audioContextManagerProvider);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  currentFocus != null ? Icons.volume_up : Icons.volume_off,
                  color: currentFocus != null
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 12),
                Text(
                  'Active Focus: ${currentFocus?.name ?? 'None'}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildStatusChip(
                  context,
                  'Ducked',
                  manager.isDucked,
                  Icons.volume_down,
                ),
                const SizedBox(width: 8),
                _buildStatusChip(
                  context,
                  'Paused',
                  manager.isPausedByContext,
                  Icons.pause_circle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    String label,
    bool active,
    IconData icon,
  ) {
    return Chip(
      avatar: Icon(icon, size: 16, color: active ? Colors.white : Colors.grey),
      label: Text(
        label,
        style: TextStyle(
          color: active ? Colors.white : Colors.grey,
          fontSize: 12,
        ),
      ),
      backgroundColor: active
          ? Theme.of(context).colorScheme.primary
          : Colors.grey.shade200,
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.only(right: 8),
    );
  }
}
