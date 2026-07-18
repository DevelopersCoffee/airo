import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import '../../../../core/auth/repositories/user_profile_repository.dart';
import '../../../../core/providers/app_theme_provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/locale_settings.dart';
import 'audio_settings_screen.dart';
import 'playback_settings_screen.dart';

/// Mobile settings hub (CV item 3): the mobile counterpart to
/// [TvSettingsScreen] — a single scrollable list rather than a rail/detail
/// split, since phone screens don't have room for a persistent side rail.
/// Aggregates appearance, quick audio toggles, currency, and links to the
/// dedicated Audio/Playback/Source screens that previously lived inline in
/// `ProfileScreen`.
class SettingsHubScreen extends ConsumerWidget {
  const SettingsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
            title: const Text('Bedtime Mode'),
            subtitle: const Text('Auto-enable at 22:30'),
            trailing: Switch(
              value: false,
              onChanged: (value) {
                // TODO: Implement bedtime mode toggle
              },
            ),
          ),

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

          const _CurrencySelector(),

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
        ],
      ),
    );
  }
}

class _CurrencySelector extends ConsumerWidget {
  const _CurrencySelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(localeSettingsProvider);
    final selectedCurrency = SupportedCurrency.fromCode(settings.currency);

    return ListTile(
      leading: const Icon(Icons.payments_outlined),
      title: const Text('Currency'),
      subtitle: Text('${selectedCurrency.code} (${selectedCurrency.symbol})'),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCurrency.code,
          items: SupportedCurrency.values.map((currency) {
            return DropdownMenuItem<String>(
              value: currency.code,
              child: Text('${currency.symbol} ${currency.code}'),
            );
          }).toList(),
          onChanged: (value) async {
            if (value == null || value == settings.currency) return;

            final updatedSettings = settings.copyWith(currency: value);
            await ref
                .read(localeSettingsProvider.notifier)
                .updateSettings(updatedSettings);

            final repository = ref.read(userProfileRepositoryProvider);
            final currentProfile = (await repository.getCurrentProfile())
                .getOrNull();
            if (currentProfile != null) {
              await repository.updateProfile(localeSettings: updatedSettings);
              ref.invalidate(currentUserProfileProvider);
            }
          },
        ),
      ),
    );
  }
}
