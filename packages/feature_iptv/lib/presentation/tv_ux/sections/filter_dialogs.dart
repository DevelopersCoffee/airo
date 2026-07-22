import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// D-pad-safe list of values for one responsive-channel filter.
class FilterOptionDialog extends StatefulWidget {
  const FilterOptionDialog({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.onClear,
    required this.onClose,
    this.emptyResult = false,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final bool emptyResult;

  @override
  State<FilterOptionDialog> createState() => _FilterOptionDialogState();
}

class _FilterOptionDialogState extends State<FilterOptionDialog> {
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final options = [...widget.options]..sort();
    final displayed = _ascending ? options : options.reversed.toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TvFocusable(
                    semanticLabel: 'Sort ${widget.title}',
                    onSelect: () => setState(() => _ascending = !_ascending),
                    child: IconButton(
                      tooltip: 'Sort A to Z',
                      onPressed: () => setState(() => _ascending = !_ascending),
                      icon: Icon(_ascending ? Icons.sort_by_alpha : Icons.sort),
                    ),
                  ),
                  TvFocusable(
                    semanticLabel: 'Close ${widget.title}',
                    onSelect: widget.onClose,
                    child: IconButton(
                      tooltip: 'Close',
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.emptyResult)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Expanded(child: Text('No channels match')),
                      TvFocusable(
                        semanticLabel: 'Clear filters',
                        onSelect: widget.onClear,
                        child: TextButton(
                          onPressed: widget.onClear,
                          child: const Text('Clear filters'),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: displayed.length,
                  itemBuilder: (context, index) {
                    final option = displayed[index];
                    final selected = option == widget.selectedValue;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: TvFocusable(
                        key: ValueKey('filter-option-$option'),
                        autofocus: index == 0,
                        semanticLabel: option,
                        onSelect: () => widget.onSelected(option),
                        child: ListTile(
                          leading: selected ? const Icon(Icons.check) : null,
                          title: Text(option),
                          onTap: () => widget.onSelected(option),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showFilterOptionDialog({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String? selectedValue,
  required ValueChanged<String> onSelected,
  required VoidCallback onClear,
  bool emptyResult = false,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => FilterOptionDialog(
      title: title,
      options: options,
      selectedValue: selectedValue,
      emptyResult: emptyResult,
      onSelected: (value) {
        onSelected(value);
        Navigator.of(dialogContext).pop();
      },
      onClear: () {
        onClear();
        Navigator.of(dialogContext).pop();
      },
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
  );
}
