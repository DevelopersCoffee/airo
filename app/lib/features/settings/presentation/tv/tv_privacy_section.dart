import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/aika_stream_local_data_deletion.dart';
import '../../../../core/providers/streaming_telemetry_consent_provider.dart';

/// Privacy settings for the TV settings screen (CV-022): the streaming
/// QoE telemetry opt-in (F7.5, Phase 1 Task 7) and the local data-deletion
/// path required for Play Data Safety.
class TvPrivacySection extends ConsumerWidget {
  const TvPrivacySection({
    super.key,
    this.showTelemetry = true,
    this.deleteFirst = false,
  });

  /// Compact Aika Stream hub hides telemetry; only `main_tv.dart` boots the
  /// streaming logger today, so a phone toggle would persist with no live
  /// service. The 10-foot rail keeps the consent rows.
  final bool showTelemetry;

  /// Compact hub leads with delete; the TV rail keeps telemetry first.
  final bool deleteFirst;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(streamingTelemetryConsentProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final telemetry = <Widget>[
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
        onSelect: () => ref
            .read(streamingTelemetryConsentProvider.notifier)
            .setEnabled(true),
        colorScheme: colorScheme,
      ),
      const SizedBox(height: 8),
      _ConsentOption(
        label: "Don't share",
        isSelected: !enabled,
        autofocus: false,
        onSelect: () => ref
            .read(streamingTelemetryConsentProvider.notifier)
            .setEnabled(false),
        colorScheme: colorScheme,
      ),
    ];

    final localData = <Widget>[
      Text(
        'Local data',
        style: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          'Aika Stream does not create an account. Playlists, credentials, '
          'favorites, and history stay on this device. Delete local data '
          'to wipe them without uninstalling.',
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
      ),
      TvFocusable(
        onSelect: () => _confirmDeleteLocalData(context, ref),
        semanticLabel: 'Delete local data',
        semanticButton: true,
        child: FilledButton.tonal(
          onPressed: () => _confirmDeleteLocalData(context, ref),
          child: const Text('Delete local data'),
        ),
      ),
    ];

    final children = <Widget>[
      if (deleteFirst) ...[
        ...localData,
        if (showTelemetry) ...[const SizedBox(height: 32), ...telemetry],
      ] else ...[
        if (showTelemetry) ...[...telemetry, const SizedBox(height: 32)],
        ...localData,
      ],
    ];

    return ListView(children: children);
  }

  Future<void> _confirmDeleteLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete local data?'),
        content: const Text(
          'This removes saved sources and credentials, the program guide, '
          'favorites, watch history, and preferences on this device. It '
          'cannot be undone.',
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(dialogContext).pop(false),
            semanticLabel: 'Cancel',
            semanticButton: true,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          TvFocusable(
            onSelect: () => Navigator.of(dialogContext).pop(true),
            semanticLabel: 'Delete',
            semanticButton: true,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(aikaStreamLocalDataDeleterProvider)();
    } catch (_) {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Could not delete local data'),
          content: const Text(
            'Try again, or clear Aika Stream storage in Android settings.',
          ),
          actions: [
            TvFocusable(
              autofocus: true,
              onSelect: () => Navigator.of(dialogContext).pop(),
              semanticLabel: 'OK',
              semanticButton: true,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      );
      return;
    }
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Local data deleted'),
        content: const Text(
          'Aika Stream on this device is reset. Restart the app if sources '
          'or favorites still appear.',
        ),
        actions: [
          TvFocusable(
            autofocus: true,
            onSelect: () => Navigator.of(dialogContext).pop(),
            semanticLabel: 'OK',
            semanticButton: true,
            child: TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
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
