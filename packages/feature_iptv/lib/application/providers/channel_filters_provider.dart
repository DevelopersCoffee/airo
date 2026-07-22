import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';

import 'iptv_providers.dart' show sharedPreferencesProvider;

const channelFilterSearchStorageKey = 'iptv_filter_search';
const channelFilterCategoryStorageKey = 'iptv_filter_category';
const channelFilterCountryStorageKey = 'iptv_filter_country';
const channelFilterLanguageStorageKey = 'iptv_filter_language';

/// Metadata eligible for display in the responsive channel browser.
///
/// Country and language stay nullable because an [IPTVChannel]'s model
/// defaults cannot prove that a playlist supplied either value. Callers may
/// populate them only from a verified playlist field or enrichment match.
class ChannelBrowseMetadata extends Equatable {
  const ChannelBrowseMetadata({this.country, this.language});

  final String? country;
  final String? language;

  @override
  List<Object?> get props => [country, language];
}

class ChannelFilters extends Equatable {
  const ChannelFilters({
    this.search = '',
    this.category,
    this.country,
    this.language,
  });

  final String search;
  final String? category;
  final String? country;
  final String? language;

  bool get isActive =>
      search.isNotEmpty ||
      category != null ||
      country != null ||
      language != null;

  ChannelFilters copyWith({
    String? search,
    String? category,
    String? country,
    String? language,
    bool clearCategory = false,
    bool clearCountry = false,
    bool clearLanguage = false,
  }) {
    return ChannelFilters(
      search: search ?? this.search,
      category: clearCategory ? null : category ?? this.category,
      country: clearCountry ? null : country ?? this.country,
      language: clearLanguage ? null : language ?? this.language,
    );
  }

  @override
  List<Object?> get props => [search, category, country, language];
}

class ChannelFiltersNotifier extends StateNotifier<ChannelFilters> {
  ChannelFiltersNotifier(this._ref) : super(const ChannelFilters()) {
    unawaited(_load());
  }

  final Ref _ref;

  void setSearch(String value) {
    _update(state.copyWith(search: value.trim()));
  }

  void setCategory(String? value) {
    _update(state.copyWith(category: value, clearCategory: value == null));
  }

  void setCountry(String? value) {
    _update(state.copyWith(country: value, clearCountry: value == null));
  }

  void setLanguage(String? value) {
    _update(state.copyWith(language: value, clearLanguage: value == null));
  }

  void clear() => _update(const ChannelFilters());

  void restore(ChannelFilters filters) => _update(filters);

  void _update(ChannelFilters next) {
    state = next;
    unawaited(_save(next));
  }

  Future<void> _load() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      state = ChannelFilters(
        search: prefs.getString(channelFilterSearchStorageKey) ?? '',
        category: prefs.getString(channelFilterCategoryStorageKey),
        country: prefs.getString(channelFilterCountryStorageKey),
        language: prefs.getString(channelFilterLanguageStorageKey),
      );
    } catch (_) {
      // Preference failures leave the browser usable with empty filters.
    }
  }

  Future<void> _save(ChannelFilters filters) async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      await Future.wait([
        prefs.setString(channelFilterSearchStorageKey, filters.search),
        _setOptional(
          key: channelFilterCategoryStorageKey,
          value: filters.category,
        ),
        _setOptional(
          key: channelFilterCountryStorageKey,
          value: filters.country,
        ),
        _setOptional(
          key: channelFilterLanguageStorageKey,
          value: filters.language,
        ),
      ]);
    } catch (_) {
      // Preference failures must not prevent local browsing.
    }
  }

  Future<bool> _setOptional({required String key, required String? value}) {
    final prefs = _ref.read(sharedPreferencesProvider);
    return value == null ? prefs.remove(key) : prefs.setString(key, value);
  }
}

final channelFiltersProvider =
    StateNotifierProvider<ChannelFiltersNotifier, ChannelFilters>(
      (ref) => ChannelFiltersNotifier(ref),
    );

enum ChannelSortColumn { name, category, country, language, type }

class ChannelSort extends Equatable {
  const ChannelSort({
    this.column = ChannelSortColumn.name,
    this.ascending = true,
  });

  final ChannelSortColumn column;
  final bool ascending;

  ChannelSort toggle(ChannelSortColumn nextColumn) {
    if (nextColumn != column) {
      return ChannelSort(column: nextColumn);
    }
    return ChannelSort(column: column, ascending: !ascending);
  }

  @override
  List<Object?> get props => [column, ascending];
}

final channelSortProvider = StateProvider<ChannelSort>(
  (ref) => const ChannelSort(),
);

class ChannelFilterDimensions {
  const ChannelFilterDimensions({
    required this.categories,
    required this.countries,
    required this.languages,
  });

  final Set<String> categories;
  final Set<String> countries;
  final Set<String> languages;
}

ChannelFilterDimensions channelFilterDimensions({
  required Iterable<IPTVChannel> channels,
  required Map<String, ChannelBrowseMetadata> metadataByChannelId,
}) {
  final categories = <String>{};
  final countries = <String>{};
  final languages = <String>{};
  for (final channel in channels) {
    if (channel.group.isNotEmpty) categories.add(channel.group);
    final metadata = metadataByChannelId[channel.id];
    if (_isPresent(metadata?.country)) countries.add(metadata!.country!);
    if (_isPresent(metadata?.language)) languages.add(metadata!.language!);
  }
  return ChannelFilterDimensions(
    categories: Set.unmodifiable(categories),
    countries: Set.unmodifiable(countries),
    languages: Set.unmodifiable(languages),
  );
}

List<IPTVChannel> applyChannelFilters({
  required Iterable<IPTVChannel> channels,
  required ChannelFilters filters,
  required Map<String, ChannelBrowseMetadata> metadataByChannelId,
}) {
  final query = filters.search.toLowerCase();
  return channels
      .where((channel) {
        final metadata = metadataByChannelId[channel.id];
        final matchesQuery =
            query.isEmpty ||
            channel.name.toLowerCase().contains(query) ||
            channel.group.toLowerCase().contains(query);
        return matchesQuery &&
            (filters.category == null || channel.group == filters.category) &&
            (filters.country == null || metadata?.country == filters.country) &&
            (filters.language == null ||
                metadata?.language == filters.language);
      })
      .toList(growable: false);
}

List<IPTVChannel> sortChannels({
  required Iterable<IPTVChannel> channels,
  required Map<String, ChannelBrowseMetadata> metadataByChannelId,
  required ChannelSort sort,
}) {
  final sorted = List<IPTVChannel>.of(channels);
  sorted.sort((left, right) {
    final leftValue = _sortValue(
      left,
      metadataByChannelId[left.id],
      sort.column,
    );
    final rightValue = _sortValue(
      right,
      metadataByChannelId[right.id],
      sort.column,
    );
    final result = _compareNullable(leftValue, rightValue);
    return sort.ascending ? result : -result;
  });
  return sorted;
}

String? _sortValue(
  IPTVChannel channel,
  ChannelBrowseMetadata? metadata,
  ChannelSortColumn column,
) {
  return switch (column) {
    ChannelSortColumn.name => channel.name,
    ChannelSortColumn.category => channel.group,
    ChannelSortColumn.country => metadata?.country,
    ChannelSortColumn.language => metadata?.language,
    ChannelSortColumn.type => channel.isAudioOnly ? 'audio' : 'live',
  };
}

int _compareNullable(String? left, String? right) {
  final leftPresent = _isPresent(left);
  final rightPresent = _isPresent(right);
  if (!leftPresent && !rightPresent) return 0;
  if (!leftPresent) return 1;
  if (!rightPresent) return -1;
  return left!.toLowerCase().compareTo(right!.toLowerCase());
}

bool _isPresent(String? value) => value != null && value.isNotEmpty;
