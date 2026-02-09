import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/beats_provider.dart';
import '../../domain/models/beats_models.dart';
import '../../domain/repositories/beats_repository.dart';

/// Search bar widget for Beats music search
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
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _checkClipboard();
    } else {
      setState(() {
        _showClipboardPrompt = false;
      });
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
      }
    } catch (_) {
      // Clipboard access may fail on some platforms
    }
  }

  void _onSearchChanged(String value) {
    ref.read(beatsSearchStateProvider.notifier).search(value);
  }

  void _useClipboardUrl() {
    if (_clipboardUrl != null) {
      _controller.text = _clipboardUrl!;
      _onSearchChanged(_clipboardUrl!);
      setState(() {
        _showClipboardPrompt = false;
      });
    }
  }

  void _clearSearch() {
    _controller.clear();
    ref.read(beatsSearchStateProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(beatsSearchStateProvider);
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
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
                      onPressed: _clearSearch,
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
            ),
          ),
        ),
        if (_showClipboardPrompt && _clipboardUrl != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              child: ListTile(
                leading: const Icon(Icons.content_paste),
                title: const Text('Paste from clipboard'),
                subtitle: Text(
                  _clipboardUrl!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: _useClipboardUrl,
              ),
            ),
          ),
        if (searchState.state == BeatsSearchState.searching ||
            searchState.state == BeatsSearchState.resolving)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(),
          ),
      ],
    );
  }
}

