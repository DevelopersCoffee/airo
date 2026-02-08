import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/beats_provider.dart';
import '../../domain/repositories/beats_repository.dart';

/// Search bar for Beats - supports both search queries and URL paste
class BeatsSearchBar extends ConsumerStatefulWidget {
  const BeatsSearchBar({super.key});

  @override
  ConsumerState<BeatsSearchBar> createState() => _BeatsSearchBarState();
}

class _BeatsSearchBarState extends ConsumerState<BeatsSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _showClipboardPrompt = false;
  String? _clipboardUrl;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && BeatsUrlPatterns.isSupported(data!.text!)) {
        setState(() {
          _showClipboardPrompt = true;
          _clipboardUrl = data.text;
        });
      } else {
        setState(() {
          _showClipboardPrompt = false;
          _clipboardUrl = null;
        });
      }
    } catch (e) {
      // Clipboard access may fail on some platforms
    }
  }

  void _onSearchChanged(String value) {
    ref.read(beatsSearchStateProvider.notifier).search(value);
  }

  void _onClear() {
    _controller.clear();
    ref.read(beatsSearchStateProvider.notifier).clear();
    setState(() {
      _showClipboardPrompt = false;
    });
  }

  void _onPasteFromClipboard() {
    if (_clipboardUrl != null) {
      _controller.text = _clipboardUrl!;
      ref.read(beatsSearchStateProvider.notifier).resolveUrl(_clipboardUrl!);
      setState(() {
        _showClipboardPrompt = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(beatsSearchStateProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search bar
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(28),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search or paste YouTube URL...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: _onClear,
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),

        // Clipboard prompt
        if (_showClipboardPrompt && searchState.state == BeatsSearchState.idle)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: _onPasteFromClipboard,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.content_paste,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Play from clipboard',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onPrimaryContainer,
                              ),
                            ),
                            Text(
                              _clipboardUrl ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.play_arrow,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
