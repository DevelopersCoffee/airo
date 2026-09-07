import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/epg_catalog_provider.dart';
import '../../application/providers/channel_filters_provider.dart'
    show countryDisplayLabel;
import '../../application/providers/guide_providers.dart';
import 'adaptive_iptv_sheet.dart';

/// Lets the user pick a guide from the published catalog, or (under
/// "Advanced") add/refresh/remove a raw XMLTV URL directly. A ready-to-use
/// widget — CV-022 (TV settings screen, not yet built) is expected to
/// present this via `showModalBottomSheet` or embed it directly; this task
/// only builds and tests the widget itself.
class XmltvSourceSheet extends ConsumerStatefulWidget {
  const XmltvSourceSheet({super.key});

  @override
  ConsumerState<XmltvSourceSheet> createState() => _XmltvSourceSheetState();
}

class _XmltvSourceSheetState extends ConsumerState<XmltvSourceSheet> {
  final _urlController = TextEditingController();
  final _catalogSearchController = TextEditingController();
  bool _isRefreshing = false;
  String? _refreshFeedback;
  String? _applyingCountryCode;
  String? _catalogFeedback;

  @override
  void dispose() {
    _urlController.dispose();
    _catalogSearchController.dispose();
    super.dispose();
  }

  Future<void> _saveAndRefresh() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isRefreshing = true;
      _refreshFeedback = null;
    });

    try {
      await ref.read(xmltvSourceRefreshServiceProvider).refresh(url);
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Guide refreshed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Refresh failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ref.invalidate(xmltvSourceConfigProvider);
        ref.invalidate(guidePagedWindowProvider);
      }
    }
  }

  Future<void> _removeSource() async {
    await ref.read(xmltvSourceStoreProvider).clear();
    if (!mounted) return;
    ref.invalidate(xmltvSourceConfigProvider);
    ref.invalidate(guidePagedWindowProvider);
  }

  Future<void> _useCatalogEntry(EpgCatalogEntry entry) async {
    setState(() {
      _applyingCountryCode = entry.countryCode;
      _catalogFeedback = null;
    });
    try {
      final manifestUrl = ref.read(epgCatalogManifestUrlProvider);
      await ref
          .read(xmltvSourceRefreshServiceProvider)
          .refreshSystemGuidesForCountries(
            manifestUrl: manifestUrl,
            countries: {entry.countryCode},
          );
      if (!mounted) return;
      setState(
        () => _catalogFeedback = 'Guide applied for ${entry.countryCode}.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _catalogFeedback = 'Could not apply guide: $e');
    } finally {
      if (mounted) {
        setState(() => _applyingCountryCode = null);
        ref.invalidate(xmltvSourceConfigProvider);
        ref.invalidate(guidePagedWindowProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(xmltvSourceConfigProvider);
    final catalogAsync = ref.watch(epgCatalogProvider);
    final query = _catalogSearchController.text.trim().toLowerCase();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Browse guides', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: _catalogSearchController,
            decoration: const InputDecoration(
              labelText: 'Search by country',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          catalogAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, _) => const Text('Could not load the guide catalog.'),
            data: (entries) {
              if (entries.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No published guides available yet — use Advanced '
                    'below to add one manually.',
                  ),
                );
              }
              final filtered = query.isEmpty
                  ? entries
                  : entries
                        .where(
                          (entry) => countryDisplayLabel(
                            entry.countryCode,
                          ).toLowerCase().contains(query),
                        )
                        .toList(growable: false);
              if (filtered.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No guides match your search.'),
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final entry = filtered[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(countryDisplayLabel(entry.countryCode)),
                      subtitle: Text(
                        '${entry.channelCount} channels · '
                        '${entry.programmeCount} programmes',
                      ),
                      trailing: TvFocusable(
                        onSelect: _applyingCountryCode == null
                            ? () => _useCatalogEntry(entry)
                            : null,
                        semanticLabel: 'Use guide for ${entry.countryCode}',
                        semanticButton: true,
                        child: FilledButton(
                          onPressed: _applyingCountryCode == null
                              ? () => _useCatalogEntry(entry)
                              : null,
                          child: _applyingCountryCode == entry.countryCode
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Use'),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (_catalogFeedback != null) ...[
            const SizedBox(height: 8),
            Text(_catalogFeedback!),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Advanced: custom URL'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            children: [
              configAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (error, _) =>
                    Text('Could not load source config: $error'),
                data: (config) {
                  if (config == null) {
                    return const Text('No XMLTV source configured yet.');
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Current source: ${config.url}'),
                      const SizedBox(height: 4),
                      Text(
                        config.lastRefreshedAt != null
                            ? 'Last refreshed: ${config.lastRefreshedAt}'
                            : 'Never refreshed successfully.',
                      ),
                      if (config.lastError != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          config.lastError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      TvFocusable(
                        onSelect: _removeSource,
                        semanticLabel: 'Remove source',
                        semanticButton: true,
                        child: TextButton(
                          onPressed: _removeSource,
                          child: const Text('Remove source'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'XMLTV URL',
                  hintText: 'https://example.com/guide.xml.gz',
                  helperText:
                      'Paste an XMLTV URL or .xml.gz. HTML schedule pages will fail.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TvFocusable(
                onSelect: _isRefreshing ? null : _saveAndRefresh,
                semanticLabel: 'Save & Refresh',
                semanticButton: true,
                child: FilledButton(
                  onPressed: _isRefreshing ? null : _saveAndRefresh,
                  child: _isRefreshing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save & Refresh'),
                ),
              ),
              if (_refreshFeedback != null) ...[
                const SizedBox(height: 8),
                Text(_refreshFeedback!),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Presents [XmltvSourceSheet] as an adaptive sheet — the phone Settings
/// hub entry point ("EPG Guide Source") uses this; the TV variant embeds
/// the sheet widget directly.
Future<void> showXmltvSourceSheet(BuildContext context) async {
  await showAdaptiveIptvSheet<void>(
    context: context,
    maxWidth: 640,
    builder: (_) => const XmltvSourceSheet(),
  );
}
