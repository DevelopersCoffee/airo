import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/local_iptv_search_providers.dart';
import '../../domain/local_iptv_search.dart';

/// TV-safe local search results panel (CV-006 AUTO-003): grouped channel and
/// program results for [localIptvSearchQueryProvider], focus-safe and
/// overflow-safe at TV viewport sizes.
class LocalSearchResultsPanel extends ConsumerWidget {
  const LocalSearchResultsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(localIptvSearchQueryProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (query.trim().isEmpty) {
      return Center(
        child: Text(
          'Search your channels and guide',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final resultsAsync = ref.watch(localIptvSearchResultsProvider);

    return resultsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('Search failed. Try again.')),
      data: (results) {
        if (results.isEmpty) {
          return Center(
            child: Text(
              'No results for "$query"',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final channelResults = results
            .where((r) => r.type == LocalIptvSearchResultType.channel)
            .toList(growable: false);
        final programResults = results
            .where((r) => r.type == LocalIptvSearchResultType.program)
            .toList(growable: false);

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            if (channelResults.isNotEmpty) ...[
              _SectionHeader('Channels'),
              const SizedBox(height: 8),
              for (var i = 0; i < channelResults.length; i++)
                _ResultRow(result: channelResults[i], autofocus: i == 0),
              const SizedBox(height: 20),
            ],
            if (programResults.isNotEmpty) ...[
              _SectionHeader('Guide'),
              const SizedBox(height: 8),
              for (var i = 0; i < programResults.length; i++)
                _ResultRow(
                  result: programResults[i],
                  autofocus: channelResults.isEmpty && i == 0,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _ResultRow extends ConsumerWidget {
  const _ResultRow({required this.result, this.autofocus = false});

  final LocalIptvSearchResult result;
  final bool autofocus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isProgram = result.type == LocalIptvSearchResultType.program;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TvFocusable(
        autofocus: autofocus,
        onSelect: () {
          if (isProgram) return;
          final channels = ref.read(iptvChannelsProvider).value ?? const [];
          for (final channel in channels) {
            if (channel.id == result.channelId) {
              ref.read(iptvStreamingServiceProvider).playChannel(channel);
              ref.read(addToRecentlyWatchedProvider(channel));
              break;
            }
          }
        },
        semanticLabel: result.title,
        semanticHint: isProgram
            ? 'Guide result for ${result.subtitle ?? result.title}'
            : 'Press OK to play this channel',
        semanticButton: true,
        borderRadius: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isProgram ? Icons.live_tv_rounded : Icons.tv_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        result.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (result.subtitle != null)
                        Text(
                          result.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (result.isFavorite)
                  Icon(Icons.favorite, size: 16, color: colorScheme.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
