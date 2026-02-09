import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../application/providers/search_provider.dart';
import '../../domain/models/unified_media_content.dart';
import '../widgets/media_search_bar.dart';

/// Screen displaying search results with recent searches and suggestions.
///
/// Features:
/// - Search bar with 300ms debounce
/// - Recent searches section
/// - Suggested categories section
/// - Results grouped by type (Music/TV)
class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({super.key});

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final searchState = ref.watch(mediaSearchProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Search'), centerTitle: true),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: MediaSearchBar(autofocus: true),
          ),

          // Content area
          Expanded(child: _buildContent(context, theme, searchState)),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    MediaSearchState searchState,
  ) {
    // Show results if searching with results
    if (searchState.isSearchActive && searchState.hasResults) {
      return _buildResults(context, theme, searchState);
    }

    // Show loading indicator if searching
    if (searchState.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show no results message if query but no results
    if (searchState.isSearchActive && !searchState.hasResults) {
      return _buildNoResults(context, theme, searchState.query);
    }

    // Show suggestions (recent searches + suggested categories)
    return _buildSuggestions(context, theme, searchState);
  }

  Widget _buildResults(
    BuildContext context,
    ThemeData theme,
    MediaSearchState searchState,
  ) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Music results
        if (searchState.musicResults.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Music', Icons.music_note),
          ...searchState.musicResults
              .take(10)
              .map((content) => _buildResultTile(context, content)),
          const SizedBox(height: 16),
        ],

        // TV results
        if (searchState.tvResults.isNotEmpty) ...[
          _buildSectionHeader(theme, 'TV', Icons.tv),
          ...searchState.tvResults
              .take(10)
              .map((content) => _buildResultTile(context, content)),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, UnifiedMediaContent content) {
    return ListTile(
      leading: content.thumbnailUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                content.thumbnailUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(content),
              ),
            )
          : _buildPlaceholder(content),
      title: Text(content.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: content.subtitle != null
          ? Text(
              content.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Icon(
        content.isMusic ? Icons.music_note : Icons.tv,
        size: 16,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onTap: () {
        // Add to recent and navigate
        ref
            .read(mediaSearchProvider.notifier)
            .addToRecentSearches(content.title);
        // TODO: Navigate to content detail or play
        Navigator.pop(context, content);
      },
    );
  }

  Widget _buildPlaceholder(UnifiedMediaContent content) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        content.isMusic ? Icons.music_note : Icons.tv,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildNoResults(BuildContext context, ThemeData theme, String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords or check spelling',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(
    BuildContext context,
    ThemeData theme,
    MediaSearchState searchState,
  ) {
    final suggestedCategories = ref.watch(suggestedCategoriesProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        // Recent searches
        if (searchState.recentSearches.isNotEmpty) ...[
          _buildSectionHeader(theme, 'Recent Searches', Icons.history),
          ...searchState.recentSearches.map(
            (query) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(query),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {
                  ref
                      .read(mediaSearchProvider.notifier)
                      .removeFromRecentSearches(query);
                },
              ),
              onTap: () {
                ref.read(mediaSearchProvider.notifier).search(query);
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Suggested categories
        _buildSectionHeader(theme, 'Suggestions', Icons.lightbulb_outline),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestedCategories.map((category) {
            return ActionChip(
              label: Text(category),
              onPressed: () {
                ref.read(mediaSearchProvider.notifier).search(category);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
