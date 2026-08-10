import 'package:flutter/material.dart';

import '../../domain/models/grounded_citation.dart';

/// The `GROUNDED IN` block. Rule R02: every citation chip is tappable and
/// resolves, with a hit target of at least [minimumTarget].
///
/// A [GroundingState.grounded] state with no citations renders as
/// [GroundingState.ungrounded] instead — a claim with no op behind it must
/// never render as grounded, even if a caller passes the wrong state.
class GroundedAnswerBlock extends StatelessWidget {
  const GroundedAnswerBlock({
    super.key,
    required this.state,
    this.citations = const [],
    this.onCitationTap,
  });

  final GroundingState state;
  final List<GroundedCitation> citations;
  final ValueChanged<GroundedCitation>? onCitationTap;

  /// The phone surface's stated floor. A 24 px chip is one a person misses.
  static const double minimumTarget = 48;

  bool get _isGrounded =>
      state == GroundingState.grounded && citations.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (state == GroundingState.notApplicable) return const SizedBox.shrink();

    final theme = Theme.of(context);
    if (!_isGrounded) {
      return Container(
        key: const Key('mind.ungroundedBadge'),
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: theme.colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'UNGROUNDED · not backed by a logged operation',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      key: const Key('mind.groundedBlock'),
      margin: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GROUNDED IN',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          for (final citation in citations)
            _CitationChip(citation: citation, onTap: onCitationTap),
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation, this.onTap});

  final GroundedCitation citation;
  final ValueChanged<GroundedCitation>? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = citation.contextLabel == null
        ? citation.sourceLabel
        : '${citation.sourceLabel} · ${citation.contextLabel}';

    return Semantics(
      button: true,
      label: '$label, op ${citation.opSequence}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(citation),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: GroundedAnswerBlock.minimumTarget,
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
              const SizedBox(width: 8),
              Text(
                'op ${citation.opSequence}',
                style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
