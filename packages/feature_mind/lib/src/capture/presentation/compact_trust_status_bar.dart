import 'package:flutter/material.dart';

import '../../trust/scribe_trust_state.dart';
import '../../widgets/mind_palette.dart';

/// Compact on-device / language status for active capture (`P0`).
class CompactTrustStatusBar extends StatelessWidget {
  const CompactTrustStatusBar({
    required this.state,
    super.key,
  });

  final ScribeTrustState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      key: const Key('meeting_capture_compact_trust_bar'),
      onTap: () => _showDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.circle,
              size: 10,
              color: state.processingOnDevice
                  ? MindPalette.local
                  : MindPalette.remote,
            ),
            const SizedBox(width: 6),
            Text(
              state.processingOnDevice ? 'On this device' : 'Network model',
              style: theme.textTheme.labelLarge?.copyWith(
                color: MindPalette.local,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.languageBadgeLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Transcription', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Processing',
                value: state.processingOnDevice
                    ? 'Running on this device'
                    : 'May use a networked model',
              ),
              const _DetailRow(label: 'Audio upload', value: 'No audio uploaded'),
              _DetailRow(label: 'Language', value: state.languageBadgeLabel),
              const _DetailRow(label: 'Translation', value: 'Off unless you ask'),
              if (state.honestyNote != null) ...[
                const SizedBox(height: 8),
                Text(
                  state.honestyNote!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('✓ '),
          Expanded(
            child: Text('$label: $value'),
          ),
        ],
      ),
    );
  }
}
