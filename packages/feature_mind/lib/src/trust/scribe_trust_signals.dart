import 'package:flutter/material.dart';

import '../widgets/mind_palette.dart';
import 'scribe_trust_state.dart';

/// Language badge + honest offline/on-device copy for scribe/meeting surfaces.
///
/// #1774 trust UX. Uses [MindPalette] rather than Living Console tokens so
/// Mind screens stay on the device-system visual language.
class ScribeTrustSignals extends StatelessWidget {
  const ScribeTrustSignals({required this.state, super.key});

  final ScribeTrustState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAlarm =
        state.languageMode == ScribeLanguageMode.modelMissing ||
        state.languageMode == ScribeLanguageMode.unknown;
    final badgeColor = isAlarm ? MindPalette.alarm : MindPalette.local;
    final honesty = state.honestyNote;

    return Semantics(
      container: true,
      label:
          '${state.languageBadgeLabel}. '
          '${state.offlineCopy}'
          '${honesty == null ? '' : ' $honesty'}',
      child: DecoratedBox(
        key: const Key('scribe_trust_signals'),
        decoration: BoxDecoration(
          border: Border.all(color: MindPalette.grid),
          color: MindPalette.surface.withValues(alpha: 0.35),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (state.showLanguageBadge)
                    _TrustBadge(
                      key: const Key('scribe_trust_language_badge'),
                      label: state.languageBadgeLabel,
                      color: badgeColor,
                    ),
                  _TrustBadge(
                    key: const Key('scribe_trust_offline_badge'),
                    label: state.processingOnDevice
                        ? 'On this device'
                        : 'Network model',
                    color: state.processingOnDevice
                        ? MindPalette.local
                        : MindPalette.remote,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                state.offlineCopy,
                key: const Key('scribe_trust_offline_copy'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
              if (honesty != null) ...[
                const SizedBox(height: 6),
                Text(
                  honesty,
                  key: const Key('scribe_trust_honesty_note'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isAlarm
                        ? MindPalette.alarm
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7)),
        color: color.withValues(alpha: 0.14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: color,
        ),
      ),
    );
  }
}
