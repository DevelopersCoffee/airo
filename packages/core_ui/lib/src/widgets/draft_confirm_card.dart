import 'package:flutter/material.dart';

import '../theme/airo_spacing.dart';
import 'airo_badge.dart';
import 'loading_indicator.dart';

/// Where a [DraftField]'s value came from. Renders as a provenance badge
/// so a person can tell what they typed from what a model guessed, without
/// digging into settings to find out.
enum DraftFieldProvenance { userEntered, aiExtracted }

/// One editable field in a [DraftConfirmCard]. Generic on purpose — this
/// widget carries no domain model (no `QuickExpenseDraft`, no split, no
/// receipt line item). Feature packages map their own draft type onto a
/// `List<DraftField>` and read it back through the confirm callback.
class DraftField {
  const DraftField({
    required this.label,
    required this.value,
    this.provenance = DraftFieldProvenance.userEntered,
    this.onEdit,
  });

  /// Field name, e.g. "Amount", "Category".
  final String label;

  /// The value, rendered however the caller wants — a `Text`, a chip, a
  /// dropdown trigger. This widget only lays it out; it never interprets
  /// what's inside.
  final Widget value;

  final DraftFieldProvenance provenance;

  /// Null means the field isn't editable from this card (rare — most
  /// fields should be editable, since a wrong single line item must be
  /// fixable without discarding the whole draft).
  final VoidCallback? onEdit;
}

/// The single component every LLM-extracted mutation renders through:
/// split draft, expense draft, category correction, itemized receipt
/// line edits (COINS-AI-10, `docs/superpowers/specs/2026-08-13-coins-ai-ux-surfaces-design.md`).
///
/// This widget never commits anything itself — [onConfirm], [onReject], and
/// [onRedo] are the caller's own persistence/re-extraction logic. That is
/// what makes "explicit confirm, no auto-commit" true by construction
/// rather than a convention every feature has to remember.
class DraftConfirmCard extends StatelessWidget {
  const DraftConfirmCard({
    super.key,
    required this.title,
    required this.fields,
    required this.onConfirm,
    required this.onReject,
    this.onRedo,
    this.confirmLabel = 'Confirm',
    this.rejectLabel = 'Discard',
    this.redoLabel = 'Edit & retry',
  });

  final String title;
  final List<DraftField> fields;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  /// Null hides the redo action -- not every draft has a re-extractable
  /// source (e.g. a plain category correction has nothing to "retry").
  final VoidCallback? onRedo;

  final String confirmLabel;
  final String rejectLabel;
  final String redoLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: AiroSpacing.paddingMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AiroSpacing.sm),
            for (final field in fields) _DraftFieldRow(field: field),
            const SizedBox(height: AiroSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('draft_confirm_card.reject'),
                  onPressed: onReject,
                  child: Text(rejectLabel),
                ),
                if (onRedo != null)
                  TextButton(
                    key: const ValueKey('draft_confirm_card.redo'),
                    onPressed: onRedo,
                    child: Text(redoLabel),
                  ),
                const SizedBox(width: AiroSpacing.xs),
                FilledButton(
                  key: const ValueKey('draft_confirm_card.confirm'),
                  onPressed: onConfirm,
                  child: Text(confirmLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DraftFieldRow extends StatelessWidget {
  const _DraftFieldRow({required this.field});

  final DraftField field;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAiExtracted =
        field.provenance == DraftFieldProvenance.aiExtracted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AiroSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              field.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: field.value),
          if (isAiExtracted) ...[
            const SizedBox(width: AiroSpacing.xs),
            // The badge is never color/icon-only -- its own label carries
            // the meaning, so a screen reader announces "AI-drafted", not
            // just a visual dot. (chief-ux-officer review, accessibility.)
            const AiroBadge(label: 'AI-drafted', variant: AiroBadgeVariant.neutral, size: AiroBadgeSize.sm),
          ],
          if (field.onEdit != null)
            IconButton(
              key: ValueKey('draft_confirm_card.edit.${field.label}'),
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: field.onEdit,
              tooltip: 'Edit ${field.label}',
            ),
        ],
      ),
    );
  }
}

/// The loading state a [DraftConfirmCard] is replaced by while a draft is
/// being extracted. [message] is required, not optional -- this is the
/// structural fix chief-ux-officer's review required: "no bare spinner
/// anywhere" is only true if the API makes a spinner without copy
/// impossible to construct, not a convention every call site has to
/// remember. Local inference on a 1-4B model takes seconds on mid-tier
/// hardware, not milliseconds, so the message should say that
/// ("Reading locally... a few seconds"), not just "Loading".
class DraftConfirmLoadingCard extends StatelessWidget {
  const DraftConfirmLoadingCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: AiroSpacing.paddingLg,
        child: Center(
          // liveRegion: true so a screen reader announces the honest
          // loading copy instead of silent time passing.
          child: Semantics(
            liveRegion: true,
            label: message,
            child: LoadingIndicator(
              size: LoadingIndicatorSize.medium,
              message: message,
            ),
          ),
        ),
      ),
    );
  }
}
