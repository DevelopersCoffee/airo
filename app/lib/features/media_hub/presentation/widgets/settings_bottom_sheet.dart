import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../iptv/domain/models/iptv_channel.dart';
import '../../application/providers/quality_settings_provider.dart';
import '../../domain/models/quality_settings.dart';

/// Bottom sheet for media playback settings.
///
/// Provides controls for:
/// - Video quality selection (Auto, 360p, 480p, 720p, 1080p, 4K)
/// - Playback speed selection (0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x)
/// - Audio language selection (if available)
/// - Subtitle language selection (if available)
class SettingsBottomSheet extends ConsumerWidget {
  /// Available audio languages (null = no audio options)
  final List<String>? availableAudioLanguages;

  /// Available subtitle languages (null = no subtitle options)
  final List<String>? availableSubtitleLanguages;

  /// Currently selected subtitle language
  final String? selectedSubtitleLanguage;

  /// Callback when subtitle language changes
  final ValueChanged<String?>? onSubtitleLanguageChanged;

  /// Whether to show playback speed option (typically for music only)
  final bool showPlaybackSpeed;

  /// Animation duration for transitions
  static const Duration animationDuration = Duration(milliseconds: 200);

  const SettingsBottomSheet({
    super.key,
    this.availableAudioLanguages,
    this.availableSubtitleLanguages,
    this.selectedSubtitleLanguage,
    this.onSubtitleLanguageChanged,
    this.showPlaybackSpeed = true,
  });

  /// Show the settings bottom sheet
  static Future<void> show(
    BuildContext context, {
    List<String>? availableAudioLanguages,
    List<String>? availableSubtitleLanguages,
    String? selectedSubtitleLanguage,
    ValueChanged<String?>? onSubtitleLanguageChanged,
    bool showPlaybackSpeed = true,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsBottomSheet(
        availableAudioLanguages: availableAudioLanguages,
        availableSubtitleLanguages: availableSubtitleLanguages,
        selectedSubtitleLanguage: selectedSubtitleLanguage,
        onSubtitleLanguageChanged: onSubtitleLanguageChanged,
        showPlaybackSpeed: showPlaybackSpeed,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(qualitySettingsProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            _buildDragHandle(theme),

            // Header
            _buildHeader(context, theme),

            const Divider(height: 1),

            // Settings content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Video Quality
                    _buildVideoQualitySection(context, ref, settings, theme),

                    // Playback Speed (if enabled)
                    if (showPlaybackSpeed)
                      _buildPlaybackSpeedSection(context, ref, settings, theme),

                    // Audio Language (if available)
                    if (availableAudioLanguages != null &&
                        availableAudioLanguages!.isNotEmpty)
                      _buildAudioLanguageSection(context, ref, settings, theme),

                    // Subtitle Language (if available)
                    if (availableSubtitleLanguages != null &&
                        availableSubtitleLanguages!.isNotEmpty)
                      _buildSubtitleLanguageSection(context, theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
      child: Row(
        children: [
          Icon(
            Icons.settings,
            color: theme.colorScheme.onSurface,
            semanticLabel: 'Settings',
          ),
          const SizedBox(width: 12),
          Text(
            'Playback Settings',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close settings',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVideoQualitySection(
    BuildContext context,
    WidgetRef ref,
    QualitySettings settings,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Video Quality', theme),
        ...VideoQuality.values.map(
          (quality) => _buildQualityOption(
            context,
            ref,
            quality,
            settings.videoQuality == quality,
            theme,
          ),
        ),
      ],
    );
  }

  Widget _buildQualityOption(
    BuildContext context,
    WidgetRef ref,
    VideoQuality quality,
    bool isSelected,
    ThemeData theme,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(
        isSelected ? Icons.check_circle : Icons.circle_outlined,
        color: isSelected
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
        semanticLabel: isSelected ? 'Selected' : 'Not selected',
      ),
      title: Text(
        quality.label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      subtitle: quality == VideoQuality.auto
          ? Text(
              'Adjusts automatically based on connection',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      onTap: () {
        ref.read(qualitySettingsProvider.notifier).setVideoQuality(quality);
      },
    );
  }

  Widget _buildPlaybackSpeedSection(
    BuildContext context,
    WidgetRef ref,
    QualitySettings settings,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Playback Speed', theme),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: QualitySettings.availableSpeeds.map((speed) {
              final isSelected = settings.playbackSpeed == speed;
              return ChoiceChip(
                label: Text('${speed}x'),
                selected: isSelected,
                onSelected: (_) {
                  ref
                      .read(qualitySettingsProvider.notifier)
                      .setPlaybackSpeed(speed);
                },
                selectedColor: theme.colorScheme.primaryContainer,
                labelStyle: TextStyle(
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildAudioLanguageSection(
    BuildContext context,
    WidgetRef ref,
    QualitySettings settings,
    ThemeData theme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Audio Language', theme),
        ...availableAudioLanguages!.map(
          (language) => ListTile(
            dense: true,
            leading: Icon(
              settings.audioLanguage == language
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: settings.audioLanguage == language
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              semanticLabel: settings.audioLanguage == language
                  ? 'Selected'
                  : 'Not selected',
            ),
            title: Text(language),
            onTap: () {
              ref
                  .read(qualitySettingsProvider.notifier)
                  .setAudioLanguage(language);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitleLanguageSection(BuildContext context, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Subtitles', theme),
        // Off option
        ListTile(
          dense: true,
          leading: Icon(
            selectedSubtitleLanguage == null
                ? Icons.check_circle
                : Icons.circle_outlined,
            color: selectedSubtitleLanguage == null
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            semanticLabel: selectedSubtitleLanguage == null
                ? 'Selected'
                : 'Not selected',
          ),
          title: const Text('Off'),
          onTap: () => onSubtitleLanguageChanged?.call(null),
        ),
        // Language options
        ...availableSubtitleLanguages!.map(
          (language) => ListTile(
            dense: true,
            leading: Icon(
              selectedSubtitleLanguage == language
                  ? Icons.check_circle
                  : Icons.circle_outlined,
              color: selectedSubtitleLanguage == language
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              semanticLabel: selectedSubtitleLanguage == language
                  ? 'Selected'
                  : 'Not selected',
            ),
            title: Text(language),
            onTap: () => onSubtitleLanguageChanged?.call(language),
          ),
        ),
      ],
    );
  }
}
