import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/streaming_telemetry_consent_provider.dart';

/// Privacy settings for the TV settings screen (CV-022): the streaming
/// QoE telemetry opt-in (F7.5, Phase 1 Task 7). No dedicated on/off
/// switch widget exists elsewhere in the TV UI, so this follows the
/// same selected/unselected row + check-icon pattern as
/// `TvThemeSection`/`TvPlaybackSection`'s options, applied to a
/// two-option (on/off) choice instead of picking one of several.
class TvPrivacySection extends ConsumerWidget {
  const TvPrivacySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(streamingTelemetryConsentProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            'Share anonymous streaming quality data (buffering, startup '
            'time, connection type) to help improve playback. Nothing is '
            'recorded until you turn this on.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ),
        _ConsentOption(
          label: 'Share streaming quality data',
          isSelected: enabled,
          autofocus: true,
          onSelect: () =>
              ref.read(streamingTelemetryConsentProvider.notifier).setEnabled(true),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 8),
        _ConsentOption(
          label: "Don't share",
          isSelected: !enabled,
          autofocus: false,
          onSelect: () =>
              ref.read(streamingTelemetryConsentProvider.notifier).setEnabled(false),
          colorScheme: colorScheme,
        ),
      ],
    );
  }
}

class _ConsentOption extends StatelessWidget {
  const _ConsentOption({
    required this.label,
    required this.isSelected,
    required this.autofocus,
    required this.onSelect,
    required this.colorScheme,
  });

  final String label;
  final bool isSelected;
  final bool autofocus;
  final VoidCallback onSelect;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      autofocus: autofocus,
      onSelect: onSelect,
      semanticLabel: label,
      semanticButton: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colorScheme.onSurface, fontSize: 16),
                ),
              ),
              if (isSelected) Icon(Icons.check, color: colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
