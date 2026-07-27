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

/// One row in [TvLongListPicker]'s flattened, lazily-built list: either a
/// jump-rail section header or a selectable option.
sealed class _PickerRow {
  const _PickerRow();
}

class _PickerHeaderRow extends _PickerRow {
  const _PickerHeaderRow(this.letter);
  final String letter;
}

class _PickerOptionRow extends _PickerRow {
  const _PickerOptionRow(this.value);
  final String value;
}

/// AiroTV D-pad design's TV-native long-list picker (issues/03): a left-side
/// Recent + A-Z jump rail (only populated initials) next to a lazily-built,
/// grouped option list. Used everywhere Country/Language/Category are chosen
/// from a TV remote, replacing [FilterOptionDialog]'s single eagerly-built
/// list -- which does not scale to a full-size country/channel-group list
/// without building every focusable tile up front.
///
/// issues/03-long-list-picker.md's acceptance criteria also mention a
/// Favourites rail group. The prototype it was written against
/// (`Airo TV - D-pad TV.dc.html`'s `pkData`) only defines "Recently used"
/// and A-Z groups for this screen -- there is no favourite-value concept
/// anywhere in the picker prototype, and no equivalent exists in the shipped
/// app for filter values (only channels can be favourited). Favourites is
/// intentionally omitted here as a product decision rather than built
/// speculatively against an unspecified interaction.
class TvLongListPicker extends StatefulWidget {
  const TvLongListPicker({
    super.key,
    required this.title,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    required this.onClear,
    required this.onClose,
    this.optionLabel,
    this.recentValues = const [],
  });

  final String title;
  final List<String> options;
  final String? selectedValue;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;
  final VoidCallback onClose;
  final String Function(String)? optionLabel;

  /// Most-recently-used values, most recent first. Shown as their own
  /// "Recent" group ahead of the alphabetical groups when non-empty.
  final List<String> recentValues;

  @override
  State<TvLongListPicker> createState() => _TvLongListPickerState();
}

class _TvLongListPickerState extends State<TvLongListPicker> {
  static const _rowExtent = 48.0;
  static const _recentLabel = 'Recent';

  final _scrollController = ScrollController();
  late final List<_PickerRow> _rows;
  late final List<String> _railLetters;
  late final Map<String, FocusNode> _optionFocusNodes;

  @override
  void initState() {
    super.initState();
    _buildRows();
  }

  @override
  void didUpdateWidget(covariant TvLongListPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options ||
        oldWidget.recentValues != widget.recentValues) {
      for (final node in _optionFocusNodes.values) {
        node.dispose();
      }
      _buildRows();
    }
  }

  @override
  void dispose() {
    for (final node in _optionFocusNodes.values) {
      node.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _buildRows() {
    final optionLabel = widget.optionLabel ?? (value) => value;

    final rows = <_PickerRow>[];
    final letters = <String>[];

    final presentRecent = widget.recentValues
        .where(widget.options.contains)
        .toList(growable: false);
    if (presentRecent.isNotEmpty) {
      rows.add(const _PickerHeaderRow(_recentLabel));
      letters.add(_recentLabel);
      for (final value in presentRecent) {
        rows.add(_PickerOptionRow(value));
      }
    }

    // A value already shown under Recent is not repeated in its alphabetical
    // group -- each option gets exactly one row, so its ValueKey/FocusNode
    // stays unique within the list.
    final presentRecentSet = presentRecent.toSet();
    final sortedOptions =
        widget.options
            .where((value) => !presentRecentSet.contains(value))
            .toList()
          ..sort(
            (left, right) => _sortLabel(
              optionLabel(left),
            ).compareTo(_sortLabel(optionLabel(right))),
          );

    String? currentLetter;
    for (final value in sortedOptions) {
      final sortLabel = _sortLabel(optionLabel(value));
      final letter = sortLabel.isEmpty ? '#' : sortLabel[0].toUpperCase();
      if (letter != currentLetter) {
        currentLetter = letter;
        rows.add(_PickerHeaderRow(letter));
        letters.add(letter);
      }
      rows.add(_PickerOptionRow(value));
    }

    _rows = rows;
    _railLetters = letters;
    _optionFocusNodes = {
      for (final row in rows)
        if (row is _PickerOptionRow) row.value: FocusNode(),
    };
  }

  void _jumpToGroup(String letter) {
    final headerIndex = _rows.indexWhere(
      (row) => row is _PickerHeaderRow && row.letter == letter,
    );
    if (headerIndex < 0) return;
    final target = (headerIndex * _rowExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(target);
    final firstOptionIndex = headerIndex + 1;
    if (firstOptionIndex >= _rows.length) return;
    final firstOption = _rows[firstOptionIndex];
    if (firstOption is! _PickerOptionRow) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _optionFocusNodes[firstOption.value]?.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final optionLabel = widget.optionLabel ?? (value) => value;
    final initialFocusValue =
        widget.selectedValue ??
        (widget.recentValues.isNotEmpty ? widget.recentValues.first : null) ??
        (_rows.whereType<_PickerOptionRow>().isEmpty
            ? null
            : _rows.whereType<_PickerOptionRow>().first.value);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 620),
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: TvFocusable(
                  key: const ValueKey('picker-option-all'),
                  autofocus: widget.selectedValue == null,
                  semanticLabel: _allLabelFor(widget.title),
                  onSelect: widget.onClear,
                  child: ListTile(
                    dense: true,
                    leading: widget.selectedValue == null
                        ? const Icon(Icons.check)
                        : null,
                    title: Text(_allLabelFor(widget.title)),
                    onTap: widget.onClear,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_railLetters.length > 1)
                      SizedBox(
                        key: const ValueKey('picker-jump-rail'),
                        width: 40,
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final letter in _railLetters)
                              TvFocusable(
                                key: ValueKey('picker-jump-$letter'),
                                semanticLabel: letter == _recentLabel
                                    ? 'Jump to recent'
                                    : 'Jump to $letter',
                                onSelect: () => _jumpToGroup(letter),
                                borderRadius: 6,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Center(
                                    child: Text(
                                      letter == _recentLabel ? '★' : letter,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.labelLarge,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        key: const ValueKey('picker-option-list'),
                        controller: _scrollController,
                        itemExtent: _rowExtent,
                        itemCount: _rows.length,
                        itemBuilder: (context, index) {
                          final row = _rows[index];
                          if (row is _PickerHeaderRow) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  row.letter == _recentLabel
                                      ? _recentLabel
                                      : row.letter,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.6,
                                      ),
                                ),
                              ),
                            );
                          }
                          row as _PickerOptionRow;
                          return TvFocusable(
                            key: ValueKey('picker-option-${row.value}'),
                            focusNode: _optionFocusNodes[row.value],
                            autofocus: row.value == initialFocusValue,
                            semanticLabel: optionLabel(row.value),
                            onSelect: () => widget.onSelected(row.value),
                            child: ListTile(
                              dense: true,
                              leading: row.value == widget.selectedValue
                                  ? const Icon(Icons.check)
                                  : null,
                              title: Text(optionLabel(row.value)),
                              onTap: () => widget.onSelected(row.value),
                            ),
                          );
                        },
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

Future<void> showTvLongListPicker({
  required BuildContext context,
  required String title,
  required List<String> options,
  required String? selectedValue,
  required ValueChanged<String> onSelected,
  required VoidCallback onClear,
  String Function(String)? optionLabel,
  List<String> recentValues = const [],
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => TvLongListPicker(
      title: title,
      options: options,
      selectedValue: selectedValue,
      recentValues: recentValues,
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
