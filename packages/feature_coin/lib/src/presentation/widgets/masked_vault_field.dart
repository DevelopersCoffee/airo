import 'package:flutter/material.dart';

class MaskedVaultField extends StatefulWidget {
  const MaskedVaultField({
    super.key,
    required this.label,
    required this.maskedValue,
    required this.revealValue,
    this.onCopy,
  });

  final String label;
  final String maskedValue;
  final Future<String?> Function() revealValue;
  final Future<void> Function(String value)? onCopy;

  @override
  State<MaskedVaultField> createState() => _MaskedVaultFieldState();
}

class _MaskedVaultFieldState extends State<MaskedVaultField> {
  String? _revealedValue;
  var _loading = false;

  bool get _isRevealed => _revealedValue != null;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(widget.label),
      subtitle: Text(_revealedValue ?? widget.maskedValue),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: _isRevealed
                ? 'Hide ${widget.label}'
                : 'Reveal ${widget.label}',
            icon: _loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_isRevealed ? Icons.visibility_off : Icons.visibility),
            onPressed: _loading ? null : _toggleReveal,
          ),
          if (widget.onCopy != null)
            IconButton(
              tooltip: 'Copy ${widget.label}',
              icon: const Icon(Icons.copy_outlined),
              onPressed: _isRevealed
                  ? () => widget.onCopy?.call(_revealedValue!)
                  : null,
            ),
        ],
      ),
    );
  }

  Future<void> _toggleReveal() async {
    if (_isRevealed) {
      setState(() => _revealedValue = null);
      return;
    }
    setState(() => _loading = true);
    final value = await widget.revealValue();
    if (!mounted) return;
    setState(() {
      _revealedValue = value;
      _loading = false;
    });
  }
}
