import 'package:flutter/material.dart';

/// One row in the record detail sheet. Plain fields pass [value] and no
/// [onReveal]; sensitive fields pass a masked placeholder as [value], the
/// decrypted text as [revealedValue], and an [onReveal] toggle.
class MaskedVaultField extends StatelessWidget {
  const MaskedVaultField({
    super.key,
    required this.label,
    required this.value,
    this.isRevealed = false,
    this.revealedValue,
    this.onReveal,
    this.onCopy,
  });

  final String label;
  final String value;
  final bool isRevealed;
  final String? revealedValue;
  final VoidCallback? onReveal;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    final display = isRevealed ? (revealedValue ?? value) : value;
    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.labelSmall),
      subtitle: Text(display, style: Theme.of(context).textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReveal != null)
            IconButton(
              tooltip: isRevealed ? 'Hide $label' : 'Reveal $label',
              icon: Icon(isRevealed ? Icons.visibility_off : Icons.visibility),
              onPressed: onReveal,
            ),
          if (onCopy != null)
            IconButton(
              tooltip: 'Copy $label',
              icon: const Icon(Icons.copy),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}
