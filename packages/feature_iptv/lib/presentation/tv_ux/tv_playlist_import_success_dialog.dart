import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'tv_playlist_url_dialog.dart';

/// Summary shown after a playlist import. Start Watching only dismisses —
/// it never opens Watch.
class TvPlaylistImportSuccessDialog extends StatelessWidget {
  const TvPlaylistImportSuccessDialog({
    super.key,
    required this.playlistLabel,
    required this.channelCount,
    this.countries = const [],
    this.categories = const [],
    this.onStartWatching,
  });

  TvPlaylistImportSuccessDialog.fromSummary(
    TvPlaylistImportSummary summary, {
    super.key,
    this.onStartWatching,
  }) : playlistLabel = summary.playlistLabel,
       channelCount = summary.channelCount,
       countries = summary.countries,
       categories = summary.categories;

  final String playlistLabel;
  final int channelCount;
  final List<String> countries;
  final List<String> categories;
  final VoidCallback? onStartWatching;

  void _close(BuildContext context) {
    onStartWatching?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final details = <String>[
      '$channelCount channel${channelCount == 1 ? '' : 's'}',
      ...countries.take(3),
      ...categories.take(3),
    ];

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AiroSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                playlistLabel,
                style: AiroTypography.headlineSmall.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: AiroSpacing.sm),
              Text(
                details.join(' · '),
                style: AiroTypography.bodyMedium.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AiroSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: TvFocusable(
                  autofocus: true,
                  semanticLabel: 'Start Watching',
                  semanticButton: true,
                  onSelect: () => _close(context),
                  borderRadius: AiroSpacing.radiusSm,
                  child: SizedBox(
                    height: AiroSpacing.tvMinTarget,
                    child: FilledButton(
                      onPressed: () => _close(context),
                      child: const Text('Start Watching'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
