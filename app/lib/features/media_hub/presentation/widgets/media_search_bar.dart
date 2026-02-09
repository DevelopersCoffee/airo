import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/search_provider.dart';

/// A unified search bar for Media Hub with debounced search.
///
/// Features:
/// - Placeholder: "Search channels, artists, genres…"
/// - 300ms debounced search
/// - Minimum 2 characters before search
/// - Shows recent searches on focus
/// - Clear button when text is entered
class MediaSearchBar extends ConsumerStatefulWidget {
  const MediaSearchBar({
    super.key,
    this.onFocusChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  /// Callback when focus state changes
  final void Function(bool hasFocus)? onFocusChanged;

  /// Callback when search is submitted
  final void Function(String query)? onSubmitted;

  /// Whether to autofocus the search field
  final bool autofocus;

  @override
  ConsumerState<MediaSearchBar> createState() => _MediaSearchBarState();
}

class _MediaSearchBarState extends ConsumerState<MediaSearchBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
  }

  void _onChanged(String value) {
    ref.read(mediaSearchProvider.notifier).search(value);
  }

  void _onSubmitted(String value) {
    if (value.length >= 2) {
      ref.read(mediaSearchProvider.notifier).addToRecentSearches(value);
    }
    widget.onSubmitted?.call(value);
  }

  void _clear() {
    _controller.clear();
    ref.read(mediaSearchProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(mediaSearchProvider);

    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      decoration: InputDecoration(
        hintText: 'Search channels, artists, genres…',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: searchState.query.isNotEmpty
            ? IconButton(icon: const Icon(Icons.clear), onPressed: _clear)
            : searchState.isSearching
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      onChanged: _onChanged,
      onSubmitted: _onSubmitted,
      textInputAction: TextInputAction.search,
    );
  }
}

/// A compact search icon button that expands to full search bar
class MediaSearchIconButton extends StatelessWidget {
  const MediaSearchIconButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.search),
      onPressed: onPressed,
      tooltip: 'Search',
    );
  }
}
