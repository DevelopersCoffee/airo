import 'package:flutter/material.dart';

import '../runtime/models/log_models.dart';
import 'grouped_number.dart';
import 'mind_palette.dart';

/// One row of the log, wherever the log is shown.
///
/// Carries the op number because that is what everything else cites: the
/// agent's grounded answers, the inspector, a person asking where a claim came
/// from. A row without its number breaks that chain.
class MindOpRow extends StatelessWidget {
  const MindOpRow({super.key, required this.op, this.onTap});

  final MindOp op;
  final VoidCallback? onTap;

  static const Map<SignatureState, String> _signatureLabels = {
    SignatureState.verified: 'verified',
    SignatureState.unverified: 'UNVERIFIED',
    SignatureState.unsigned: 'UNSIGNED',
  };

  /// Secondary text: the writing device, and the op number itself.
  static final Color _muted = MindPalette.ink.withValues(alpha: 0.55);

  /// Unverified is loud on purpose. It is the one state a person must not
  /// scroll past, and rendering it in the same grey as "verified" would make
  /// the column decorative.
  static final Map<SignatureState, Color> _signatureColours = {
    SignatureState.verified: MindPalette.ink.withValues(alpha: 0.6),
    SignatureState.unverified: MindPalette.alarm,
    SignatureState.unsigned: MindPalette.remote,
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    op.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        op.deviceName,
                        style: TextStyle(fontSize: 11, color: _muted),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _signatureLabels[op.signature]!,
                        key: const Key('mind.op.signature'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _signatureColours[op.signature],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'op ${groupedNumber(op.sequence)}',
              style: TextStyle(fontSize: 11, letterSpacing: 1, color: _muted),
            ),
          ],
        ),
      ),
    );
  }
}
