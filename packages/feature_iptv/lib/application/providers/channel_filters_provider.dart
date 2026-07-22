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
const channelCountryPromptCompletedStorageKey = 'iptv_country_prompt_completed';

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

  Map<String, String> toJson() => {
    'search': search,
    'category': ?category,
    'country': ?country,
    'language': ?language,
  };

  factory ChannelFilters.fromJson(Map<String, Object?> json) {
    return ChannelFilters(
      search: json['search'] as String? ?? '',
      category: json['category'] as String?,
      country: json['country'] as String?,
      language: json['language'] as String?,
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
    _update(
      state.copyWith(
        country: value,
        clearCountry: value == null,
        // A language is meaningful only within its country. Reset it whenever
        // the parent country changes so a stale selection cannot leave the
        // user with an empty browse list.
        clearLanguage: value != state.country,
      ),
    );
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

class ChannelCountryPromptNotifier extends StateNotifier<AsyncValue<bool>> {
  ChannelCountryPromptNotifier(this._ref) : super(const AsyncValue.loading()) {
    unawaited(_load());
  }

  final Ref _ref;

  Future<void> markCompleted() async {
    state = const AsyncValue.data(true);
    try {
      await _ref
          .read(sharedPreferencesProvider)
          .setBool(channelCountryPromptCompletedStorageKey, true);
    } catch (_) {
      // Preference failures must not block the TV browser.
    }
  }

  Future<void> _load() async {
    try {
      final prefs = _ref.read(sharedPreferencesProvider);
      final hasSavedCountry = _isPresent(
        prefs.getString(channelFilterCountryStorageKey),
      );
      state = AsyncValue.data(
        prefs.getBool(channelCountryPromptCompletedStorageKey) == true ||
            hasSavedCountry,
      );
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final channelCountryPromptProvider =
    StateNotifierProvider<ChannelCountryPromptNotifier, AsyncValue<bool>>(
      (ref) => ChannelCountryPromptNotifier(ref),
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

class ChannelBrowserSnapshot {
  const ChannelBrowserSnapshot({
    required this.dimensions,
    required this.visibleChannels,
  });

  final ChannelFilterDimensions dimensions;
  final List<IPTVChannel> visibleChannels;
}

/// One-entry cache for the channel browser's expensive derived state.
///
/// The IPTV catalogue is large enough that filtering/sorting thousands of rows
/// on every playback-state rebuild is visible on phones. The shell owns this
/// cache for its widget lifetime and invalidates it only when the channel list,
/// enrichment map, filter state, or sort state actually changes.
class ChannelBrowserSnapshotCache {
  Iterable<IPTVChannel>? _channels;
  Map<String, ChannelBrowseMetadata>? _metadataByChannelId;
  ChannelFilters? _filters;
  ChannelSort? _sort;
  ChannelBrowserSnapshot? _snapshot;

  ChannelBrowserSnapshot resolve({
    required Iterable<IPTVChannel> channels,
    required Map<String, ChannelBrowseMetadata> metadataByChannelId,
    required ChannelFilters filters,
    required ChannelSort sort,
  }) {
    final previous = _snapshot;
    if (previous != null &&
        identical(_channels, channels) &&
        identical(_metadataByChannelId, metadataByChannelId) &&
        _filters == filters &&
        _sort == sort) {
      return previous;
    }

    final dimensions = channelFilterDimensions(
      channels: channels,
      metadataByChannelId: metadataByChannelId,
      country: filters.country,
    );
    final visibleChannels = sortChannels(
      channels: applyChannelFilters(
        channels: channels,
        filters: filters,
        metadataByChannelId: metadataByChannelId,
      ),
      metadataByChannelId: metadataByChannelId,
      sort: sort,
    );
    final next = ChannelBrowserSnapshot(
      dimensions: dimensions,
      visibleChannels: visibleChannels,
    );

    _channels = channels;
    _metadataByChannelId = metadataByChannelId;
    _filters = filters;
    _sort = sort;
    _snapshot = next;
    return next;
  }

  void clear() {
    _channels = null;
    _metadataByChannelId = null;
    _filters = null;
    _sort = null;
    _snapshot = null;
  }
}

ChannelFilterDimensions channelFilterDimensions({
  required Iterable<IPTVChannel> channels,
  required Map<String, ChannelBrowseMetadata> metadataByChannelId,
  String? country,
}) {
  final categoriesByKey = <String, String>{};
  final countries = <String>{};
  final languages = <String>{};
  for (final channel in channels) {
    final category = categoryDisplayLabel(channel.group);
    if (category != null) {
      categoriesByKey.putIfAbsent(categoryFilterKey(category), () => category);
    }
    final metadata = metadataByChannelId[channel.id];
    final channelCountry = effectiveChannelCountry(channel, metadata);
    if (_isPresent(channelCountry)) countries.add(channelCountry!);
    if (country == null || country == channelCountry) {
      languages.addAll(effectiveChannelLanguages(channel, metadata));
    }
  }
  return ChannelFilterDimensions(
    categories: Set.unmodifiable(categoriesByKey.values.toSet()),
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
  return applyChannelScope(
        channels: channels,
        filters: filters,
        metadataByChannelId: metadataByChannelId,
      )
      .where((channel) {
        final matchesQuery =
            query.isEmpty ||
            channel.name.toLowerCase().contains(query) ||
            channel.group.toLowerCase().contains(query);
        return matchesQuery &&
            (filters.category == null ||
                categoryFilterKey(channel.group) ==
                    categoryFilterKey(filters.category!));
      })
      .toList(growable: false);
}

/// Applies the global discovery scope shared by browse and Guide. Search and
/// category are intentionally left to each surface: Guide has its own search
/// field and hidden-group rules, while country/language must remain global.
List<IPTVChannel> applyChannelScope({
  required Iterable<IPTVChannel> channels,
  required ChannelFilters filters,
  required Map<String, ChannelBrowseMetadata> metadataByChannelId,
}) {
  return channels
      .where((channel) {
        final metadata = metadataByChannelId[channel.id];
        return (filters.country == null ||
                effectiveChannelCountry(channel, metadata) ==
                    filters.country) &&
            (filters.language == null ||
                effectiveChannelLanguages(
                  channel,
                  metadata,
                ).contains(filters.language));
      })
      .toList(growable: false);
}

/// Returns verified enrichment when available, then the playlist value. The
/// latter makes user-supplied M3U values useful while enrichment is loading or
/// unavailable offline.
String? effectiveChannelCountry(
  IPTVChannel channel,
  ChannelBrowseMetadata? metadata,
) {
  return _isPresent(metadata?.country) ? metadata!.country : channel.country;
}

/// The enrichment API currently supplies one preferred language. A playlist
/// can supply several; retain all of those when no verified preference exists.
List<String> effectiveChannelLanguages(
  IPTVChannel channel,
  ChannelBrowseMetadata? metadata,
) {
  if (_isPresent(metadata?.language)) return [metadata!.language!];
  return channel.languages.where(_isPresent).toList(growable: false);
}

String countryDisplayLabel(String? value) {
  if (!_isPresent(value)) return 'Country';
  final code = value!.trim().toUpperCase();
  final name = _countryNames[code];
  if (name == null) return value;
  return '${_countryFlag(code)} $name';
}

String languageDisplayLabel(String? value) {
  if (!_isPresent(value)) return 'Language';
  final code = value!.trim().toLowerCase();
  return _languageNames[code] ?? value;
}

/// A normalized category key for picker deduplication and category filtering.
/// Keep the playlist's original group intact; this only treats case and runs
/// of whitespace as presentation-equivalent.
String categoryFilterKey(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

String? categoryDisplayLabel(String value) {
  final display = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  return display.isEmpty ? null : display;
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
    ChannelSortColumn.country => effectiveChannelCountry(channel, metadata),
    ChannelSortColumn.language =>
      effectiveChannelLanguages(channel, metadata).isEmpty
          ? null
          : effectiveChannelLanguages(channel, metadata).first,
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

String _countryFlag(String countryCode) {
  if (countryCode.length != 2) return '';
  final first = countryCode.codeUnitAt(0);
  final second = countryCode.codeUnitAt(1);
  if (first < 65 || first > 90 || second < 65 || second > 90) return '';
  return String.fromCharCodes([first + 127397, second + 127397]);
}

const _countryNames = <String, String>{
  'AD': 'Andorra',
  'AE': 'United Arab Emirates',
  'AF': 'Afghanistan',
  'AG': 'Antigua and Barbuda',
  'AI': 'Anguilla',
  'AL': 'Albania',
  'AM': 'Armenia',
  'AO': 'Angola',
  'AQ': 'Antarctica',
  'AR': 'Argentina',
  'AS': 'American Samoa',
  'AT': 'Austria',
  'AU': 'Australia',
  'AW': 'Aruba',
  'AX': 'Åland Islands',
  'AZ': 'Azerbaijan',
  'BA': 'Bosnia and Herzegovina',
  'BB': 'Barbados',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BF': 'Burkina Faso',
  'BG': 'Bulgaria',
  'BH': 'Bahrain',
  'BI': 'Burundi',
  'BJ': 'Benin',
  'BL': 'Saint Barthélemy',
  'BM': 'Bermuda',
  'BN': 'Brunei',
  'BO': 'Bolivia',
  'BQ': 'Caribbean Netherlands',
  'BR': 'Brazil',
  'BS': 'Bahamas',
  'BT': 'Bhutan',
  'BV': 'Bouvet Island',
  'BW': 'Botswana',
  'BY': 'Belarus',
  'BZ': 'Belize',
  'CA': 'Canada',
  'CC': 'Cocos Islands',
  'CD': 'Democratic Republic of the Congo',
  'CF': 'Central African Republic',
  'CG': 'Republic of the Congo',
  'CH': 'Switzerland',
  'CI': "Côte d'Ivoire",
  'CK': 'Cook Islands',
  'CL': 'Chile',
  'CM': 'Cameroon',
  'CN': 'China',
  'CO': 'Colombia',
  'CR': 'Costa Rica',
  'CU': 'Cuba',
  'CV': 'Cape Verde',
  'CW': 'Curaçao',
  'CX': 'Christmas Island',
  'CY': 'Cyprus',
  'CZ': 'Czechia',
  'DE': 'Germany',
  'DJ': 'Djibouti',
  'DK': 'Denmark',
  'DM': 'Dominica',
  'DO': 'Dominican Republic',
  'DZ': 'Algeria',
  'EC': 'Ecuador',
  'EE': 'Estonia',
  'EG': 'Egypt',
  'EH': 'Western Sahara',
  'ER': 'Eritrea',
  'ES': 'Spain',
  'ET': 'Ethiopia',
  'FI': 'Finland',
  'FJ': 'Fiji',
  'FK': 'Falkland Islands',
  'FM': 'Micronesia',
  'FO': 'Faroe Islands',
  'FR': 'France',
  'GA': 'Gabon',
  'GB': 'United Kingdom',
  'GD': 'Grenada',
  'GE': 'Georgia',
  'GF': 'French Guiana',
  'GG': 'Guernsey',
  'GH': 'Ghana',
  'GI': 'Gibraltar',
  'GL': 'Greenland',
  'GM': 'Gambia',
  'GN': 'Guinea',
  'GR': 'Greece',
  'GP': 'Guadeloupe',
  'GQ': 'Equatorial Guinea',
  'GS': 'South Georgia and the South Sandwich Islands',
  'GT': 'Guatemala',
  'GU': 'Guam',
  'GW': 'Guinea-Bissau',
  'GY': 'Guyana',
  'HK': 'Hong Kong',
  'HM': 'Heard Island and McDonald Islands',
  'HN': 'Honduras',
  'HR': 'Croatia',
  'HT': 'Haiti',
  'HU': 'Hungary',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IM': 'Isle of Man',
  'IN': 'India',
  'IO': 'British Indian Ocean Territory',
  'IQ': 'Iraq',
  'IR': 'Iran',
  'IS': 'Iceland',
  'IT': 'Italy',
  'JE': 'Jersey',
  'JM': 'Jamaica',
  'JO': 'Jordan',
  'JP': 'Japan',
  'KE': 'Kenya',
  'KG': 'Kyrgyzstan',
  'KH': 'Cambodia',
  'KI': 'Kiribati',
  'KM': 'Comoros',
  'KN': 'Saint Kitts and Nevis',
  'KP': 'North Korea',
  'KR': 'South Korea',
  'KW': 'Kuwait',
  'KY': 'Cayman Islands',
  'KZ': 'Kazakhstan',
  'LA': 'Laos',
  'LB': 'Lebanon',
  'LC': 'Saint Lucia',
  'LI': 'Liechtenstein',
  'LK': 'Sri Lanka',
  'LR': 'Liberia',
  'LS': 'Lesotho',
  'LT': 'Lithuania',
  'LU': 'Luxembourg',
  'LV': 'Latvia',
  'LY': 'Libya',
  'MA': 'Morocco',
  'MC': 'Monaco',
  'MD': 'Moldova',
  'ME': 'Montenegro',
  'MF': 'Saint Martin',
  'MG': 'Madagascar',
  'MH': 'Marshall Islands',
  'MK': 'North Macedonia',
  'ML': 'Mali',
  'MM': 'Myanmar',
  'MN': 'Mongolia',
  'MO': 'Macao',
  'MP': 'Northern Mariana Islands',
  'MQ': 'Martinique',
  'MR': 'Mauritania',
  'MS': 'Montserrat',
  'MT': 'Malta',
  'MU': 'Mauritius',
  'MV': 'Maldives',
  'MW': 'Malawi',
  'MX': 'Mexico',
  'MY': 'Malaysia',
  'MZ': 'Mozambique',
  'NA': 'Namibia',
  'NC': 'New Caledonia',
  'NE': 'Niger',
  'NF': 'Norfolk Island',
  'NG': 'Nigeria',
  'NI': 'Nicaragua',
  'NL': 'Netherlands',
  'NO': 'Norway',
  'NP': 'Nepal',
  'NR': 'Nauru',
  'NU': 'Niue',
  'NZ': 'New Zealand',
  'OM': 'Oman',
  'PA': 'Panama',
  'PE': 'Peru',
  'PF': 'French Polynesia',
  'PG': 'Papua New Guinea',
  'PH': 'Philippines',
  'PK': 'Pakistan',
  'PL': 'Poland',
  'PM': 'Saint Pierre and Miquelon',
  'PN': 'Pitcairn Islands',
  'PR': 'Puerto Rico',
  'PS': 'Palestine',
  'PT': 'Portugal',
  'PW': 'Palau',
  'PY': 'Paraguay',
  'QA': 'Qatar',
  'RE': 'Réunion',
  'RO': 'Romania',
  'RS': 'Serbia',
  'RU': 'Russia',
  'RW': 'Rwanda',
  'SA': 'Saudi Arabia',
  'SB': 'Solomon Islands',
  'SC': 'Seychelles',
  'SD': 'Sudan',
  'SE': 'Sweden',
  'SG': 'Singapore',
  'SH': 'Saint Helena',
  'SI': 'Slovenia',
  'SJ': 'Svalbard and Jan Mayen',
  'SK': 'Slovakia',
  'SL': 'Sierra Leone',
  'SM': 'San Marino',
  'SN': 'Senegal',
  'SO': 'Somalia',
  'SR': 'Suriname',
  'SS': 'South Sudan',
  'ST': 'São Tomé and Príncipe',
  'SV': 'El Salvador',
  'SX': 'Sint Maarten',
  'SY': 'Syria',
  'SZ': 'Eswatini',
  'TC': 'Turks and Caicos Islands',
  'TD': 'Chad',
  'TF': 'French Southern Territories',
  'TG': 'Togo',
  'TH': 'Thailand',
  'TJ': 'Tajikistan',
  'TK': 'Tokelau',
  'TL': 'Timor-Leste',
  'TM': 'Turkmenistan',
  'TN': 'Tunisia',
  'TO': 'Tonga',
  'TR': 'Turkey',
  'TT': 'Trinidad and Tobago',
  'TV': 'Tuvalu',
  'TW': 'Taiwan',
  'TZ': 'Tanzania',
  'UA': 'Ukraine',
  'UG': 'Uganda',
  'UM': 'United States Minor Outlying Islands',
  'US': 'United States',
  'UY': 'Uruguay',
  'UZ': 'Uzbekistan',
  'VA': 'Vatican City',
  'VC': 'Saint Vincent and the Grenadines',
  'VE': 'Venezuela',
  'VG': 'British Virgin Islands',
  'VI': 'U.S. Virgin Islands',
  'VN': 'Vietnam',
  'VU': 'Vanuatu',
  'WF': 'Wallis and Futuna',
  'WS': 'Samoa',
  'XK': 'Kosovo',
  'YE': 'Yemen',
  'YT': 'Mayotte',
  'ZA': 'South Africa',
  'ZM': 'Zambia',
  'ZW': 'Zimbabwe',
};

const _languageNames = <String, String>{
  'ar': 'Arabic',
  'de': 'German',
  'en': 'English',
  'eng': 'English',
  'es': 'Spanish',
  'fr': 'French',
  'hi': 'Hindi',
  'hin': 'Hindi',
  'id': 'Indonesian',
  'it': 'Italian',
  'ita': 'Italian',
  'ja': 'Japanese',
  'nl': 'Dutch',
  'pl': 'Polish',
  'pt': 'Portuguese',
  'ru': 'Russian',
  'tr': 'Turkish',
  'uk': 'Ukrainian',
  'vi': 'Vietnamese',
};
