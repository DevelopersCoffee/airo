import 'package:flutter/material.dart';
import 'dictionary_popup.dart';

/// SelectableText widget with built-in dictionary lookup
class SelectableTextWithDictionary extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final bool showCursor;
  final bool autofocus;

  const SelectableTextWithDictionary(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.showCursor = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      showCursor: showCursor,
      autofocus: autofocus,
      contextMenuBuilder: (context, editableTextState) {
        return _buildContextMenu(context, editableTextState);
      },
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selectedText = editableTextState.textEditingValue.selection
        .textInside(editableTextState.textEditingValue.text)
        .trim();

    final List<ContextMenuButtonItem> buttonItems =
        editableTextState.contextMenuButtonItems;

    // Add dictionary lookup button if text is selected
    if (selectedText.isNotEmpty && _isSingleWord(selectedText)) {
      buttonItems.insert(
        0,
        ContextMenuButtonItem(
          label: 'Look up "$selectedText"',
          onPressed: () {
            ContextMenuController.removeAny();
            DictionaryPopup.showBottomSheet(context, selectedText);
          },
        ),
      );
    }

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  bool _isSingleWord(String text) {
    // Check if the selected text is a single word (no spaces)
    return !text.contains(' ') && text.length > 1;
  }
}

/// Text widget wrapper that adds dictionary lookup on long press
class TextWithDictionary extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const TextWithDictionary(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showWordSelection(context),
      child: Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: overflow,
      ),
    );
  }

  void _showWordSelection(BuildContext context) {
    // Extract words from text
    final words = text.split(RegExp(r'\s+'));
    
    if (words.length == 1) {
      // Single word - show definition directly
      DictionaryPopup.showBottomSheet(context, words.first);
    } else {
      // Multiple words - show word picker
      showModalBottomSheet(
        context: context,
        builder: (context) => _WordPickerSheet(words: words),
      );
    }
  }
}

/// Sheet to pick a word for dictionary lookup
class _WordPickerSheet extends StatelessWidget {
  final List<String> words;

  const _WordPickerSheet({required this.words});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.book),
              const SizedBox(width: 12),
              Text(
                'Select a word to look up',
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: words.map((word) {
              final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
              if (cleanWord.isEmpty) return const SizedBox.shrink();
              
              return ActionChip(
                label: Text(cleanWord),
                onPressed: () {
                  Navigator.of(context).pop();
                  DictionaryPopup.showBottomSheet(context, cleanWord);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// Extension to add dictionary lookup to any Text widget
extension DictionaryTextExtension on Text {
  /// Wrap this Text widget with dictionary lookup functionality
  Widget withDictionary() {
    return TextWithDictionary(
      data ?? '',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

/// Extension to add dictionary lookup to any SelectableText widget
extension DictionarySelectableTextExtension on SelectableText {
  /// Wrap this SelectableText widget with dictionary lookup functionality
  Widget withDictionary() {
    return SelectableTextWithDictionary(
      data ?? '',
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      showCursor: showCursor,
      autofocus: autofocus,
    );
  }
}

