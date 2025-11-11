import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dictionary_popup.dart';

/// Global wrapper that makes ALL text in the app dictionary-enabled
///
/// Wrap your MaterialApp with this to enable dictionary on all text:
/// ```dart
/// DictionaryTextWrapper(
///   child: MaterialApp(...),
/// )
/// ```
class DictionaryTextWrapper extends StatelessWidget {
  final Widget child;
  final bool enabled;

  const DictionaryTextWrapper({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return DefaultTextStyle.merge(
      child: DefaultSelectionStyle(
        selectionColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        child: child,
      ),
    );
  }
}

/// Custom SelectionArea that adds dictionary lookup to context menu
class DictionarySelectionArea extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const DictionarySelectionArea({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  State<DictionarySelectionArea> createState() =>
      _DictionarySelectionAreaState();
}

class _DictionarySelectionAreaState extends State<DictionarySelectionArea> {
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();

  @override
  void dispose() {
    _selectionNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return SelectionArea(
      contextMenuBuilder: (context, selectableRegionState) {
        return _buildContextMenu(context, selectableRegionState);
      },
      child: SelectionListener(
        selectionNotifier: _selectionNotifier,
        child: widget.child,
      ),
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    SelectableRegionState selectableRegionState,
  ) {
    final List<ContextMenuButtonItem> buttonItems = [
      ...selectableRegionState.contextMenuButtonItems,
    ];

    // Add dictionary lookup button - it will use clipboard to get selected text
    buttonItems.insert(
      0,
      ContextMenuButtonItem(
        label: '📖 Look up word',
        onPressed: () async {
          ContextMenuController.removeAny();
          await _lookupFromClipboard(context);
        },
      ),
    );

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: selectableRegionState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  Future<void> _lookupFromClipboard(BuildContext context) async {
    try {
      // Copy the selected text to clipboard first (user will do this via Copy button)
      // Then read from clipboard
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';

      if (text.isEmpty) {
        if (context.mounted) {
          _showQuickLookupDialog(context);
        }
        return;
      }

      // Check if it's a single word
      if (!context.mounted) return;

      if (_isSingleWord(text)) {
        _showDictionary(context, text);
      } else if (text.split(RegExp(r'\s+')).length <= 5) {
        // Multiple words, show picker
        _showWordPicker(context, text);
      } else {
        // Too many words, show quick lookup dialog
        _showQuickLookupDialog(context);
      }
    } catch (e) {
      // If clipboard access fails, show quick lookup dialog
      if (context.mounted) {
        _showQuickLookupDialog(context);
      }
    }
  }

  void _showQuickLookupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _QuickLookupDialog(),
    );
  }

  bool _isSingleWord(String text) {
    // Check if the selected text is a single word (no spaces)
    final cleanWord = text.replaceAll(RegExp(r'[^\w\s]'), '');
    return !cleanWord.contains(' ') && cleanWord.length > 1;
  }

  void _showDictionary(BuildContext context, String word) {
    // Clean the word (remove punctuation)
    final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
    if (cleanWord.isEmpty) return;

    DictionaryPopup.showBottomSheet(context, cleanWord);
  }

  void _showWordPicker(BuildContext context, String text) {
    final words = text
        .split(RegExp(r'\s+'))
        .map((w) => w.replaceAll(RegExp(r'[^\w]'), ''))
        .where((w) => w.isNotEmpty && w.length > 1)
        .toList();

    if (words.isEmpty) return;

    if (words.length == 1) {
      _showDictionary(context, words.first);
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => _WordPickerSheet(words: words),
    );
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
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.menu_book, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Select a word to look up',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: words.map((word) {
                return ActionChip(
                  avatar: const Icon(Icons.book, size: 18),
                  label: Text(word),
                  onPressed: () {
                    Navigator.of(context).pop();
                    DictionaryPopup.showBottomSheet(context, word);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Floating action button for quick dictionary lookup
class DictionaryFAB extends StatelessWidget {
  final VoidCallback? onPressed;

  const DictionaryFAB({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: onPressed ?? () => _showQuickLookup(context),
      tooltip: 'Quick Dictionary Lookup',
      child: const Icon(Icons.menu_book),
    );
  }

  void _showQuickLookup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _QuickLookupDialog(),
    );
  }
}

/// Quick lookup dialog
class _QuickLookupDialog extends StatefulWidget {
  const _QuickLookupDialog();

  @override
  State<_QuickLookupDialog> createState() => _QuickLookupDialogState();
}

class _QuickLookupDialogState extends State<_QuickLookupDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _lookup() {
    final word = _controller.text.trim();
    if (word.isEmpty) return;

    Navigator.of(context).pop();
    DictionaryPopup.showBottomSheet(context, word);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.menu_book),
          SizedBox(width: 12),
          Text('Quick Lookup'),
        ],
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Enter a word',
          hintText: 'e.g., serendipity',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.search),
        ),
        onSubmitted: (_) => _lookup(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _lookup,
          icon: const Icon(Icons.search),
          label: const Text('Look Up'),
        ),
      ],
    );
  }
}
