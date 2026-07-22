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
    this.optionLabel,
    this.emptyResult = false,
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final String Function(String)? optionLabel;
  final bool emptyResult;

  @override
  State<FilterOptionDialog> createState() => _FilterOptionDialogState();
}

class _FilterOptionDialogState extends State<FilterOptionDialog> {
  bool _ascending = true;

  @override
  Widget build(BuildContext context) {
    final optionLabel = widget.optionLabel ?? (value) => value;
    final options = [...widget.options]
      ..sort(
        (left, right) => _sortLabel(
          optionLabel(left),
        ).compareTo(_sortLabel(optionLabel(right))),
      );
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
                child: ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: TvFocusable(
                        key: const ValueKey('filter-option-all'),
                        autofocus: displayed.isEmpty,
                        semanticLabel: _allLabelFor(widget.title),
                        onSelect: widget.onClear,
                        child: ListTile(
                          leading: widget.selectedValue == null
                              ? const Icon(Icons.check)
                              : null,
                          title: Text(_allLabelFor(widget.title)),
                          onTap: widget.onClear,
                        ),
                      ),
                    ),
                    for (var index = 0; index < displayed.length; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: TvFocusable(
                          key: ValueKey('filter-option-${displayed[index]}'),
                          autofocus: index == 0,
                          semanticLabel: optionLabel(displayed[index]),
                          onSelect: () => widget.onSelected(displayed[index]),
                          child: ListTile(
                            leading: displayed[index] == widget.selectedValue
                                ? const Icon(Icons.check)
                                : null,
                            title: Text(optionLabel(displayed[index])),
                            onTap: () => widget.onSelected(displayed[index]),
                          ),
                        ),
                      ),
                  ],
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
  String Function(String)? optionLabel,
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
      optionLabel: optionLabel,
      onClose: () => Navigator.of(dialogContext).pop(),
    ),
  );
}

String _allLabelFor(String title) {
  final normalized = title.trim().toLowerCase();
  return switch (normalized) {
    'country' || 'choose your country' => 'All Countries',
    'language' => 'All Languages',
    'category' => 'All Categories',
    _ => 'All',
  };
}

String _sortLabel(String label) {
  final codePoints = label.runes.toList(growable: false);
  var index = 0;
  while (index < codePoints.length &&
      codePoints[index] >= 0x1F1E6 &&
      codePoints[index] <= 0x1F1FF) {
    index += 1;
  }
  if (index >= 2) {
    while (index < codePoints.length &&
        String.fromCharCode(codePoints[index]).trim().isEmpty) {
      index += 1;
    }
  } else {
    index = 0;
  }
  return String.fromCharCodes(codePoints.skip(index)).toLowerCase();
}
