import 'dart:collection';

/// The thirteen public collections in the iptv-org API v1 contract.
enum IptvOrgEndpoint {
  channels,
  feeds,
  logos,
  streams,
  guides,
  categories,
  languages,
  countries,
  subdivisions,
  cities,
  regions,
  timezones,
  blocklist;

  String get fileName => '$name.json';
}

/// A boundary-validation failure for an untrusted upstream response.
final class IptvOrgSchemaException implements FormatException {
  IptvOrgSchemaException({
    required this.endpoint,
    required this.index,
    required this.field,
    required this.expected,
    required this.actual,
  });

  final IptvOrgEndpoint endpoint;
  final int index;
  final String field;
  final String expected;
  final Object? actual;

  @override
  String get message =>
      '${endpoint.name}[$index].$field expected $expected, '
      'got ${actual.runtimeType}';

  @override
  int? get offset => null;

  @override
  Object? get source => null;

  @override
  String toString() => 'IptvOrgSchemaException: $message';
}

typedef _IptvOrgRowFactory<T> =
    T Function(Map<String, Object?> json, _RowReader row);

/// Validates and materializes one endpoint collection.
///
/// The returned object is a typed, unmodifiable `List<IptvOrg…>` selected by
/// [endpoint]. Callers that know the endpoint at compile time should normally
/// use [IptvOrgApiClient]'s typed methods instead.
Object decodeIptvOrgEndpoint(IptvOrgEndpoint endpoint, Object? decoded) {
  return switch (endpoint) {
    IptvOrgEndpoint.channels => _decodeRows(
      endpoint,
      decoded,
      IptvOrgChannel._fromJson,
    ),
    IptvOrgEndpoint.feeds => _decodeRows(
      endpoint,
      decoded,
      IptvOrgFeed._fromJson,
    ),
    IptvOrgEndpoint.logos => _decodeRows(
      endpoint,
      decoded,
      IptvOrgLogo._fromJson,
    ),
    IptvOrgEndpoint.streams => _decodeRows(
      endpoint,
      decoded,
      IptvOrgStream._fromJson,
    ),
    IptvOrgEndpoint.guides => _decodeRows(
      endpoint,
      decoded,
      IptvOrgGuide._fromJson,
    ),
    IptvOrgEndpoint.categories => _decodeRows(
      endpoint,
      decoded,
      IptvOrgCategory._fromJson,
    ),
    IptvOrgEndpoint.languages => _decodeRows(
      endpoint,
      decoded,
      IptvOrgLanguage._fromJson,
    ),
    IptvOrgEndpoint.countries => _decodeRows(
      endpoint,
      decoded,
      IptvOrgCountry._fromJson,
    ),
    IptvOrgEndpoint.subdivisions => _decodeRows(
      endpoint,
      decoded,
      IptvOrgSubdivision._fromJson,
    ),
    IptvOrgEndpoint.cities => _decodeRows(
      endpoint,
      decoded,
      IptvOrgCity._fromJson,
    ),
    IptvOrgEndpoint.regions => _decodeRows(
      endpoint,
      decoded,
      IptvOrgRegion._fromJson,
    ),
    IptvOrgEndpoint.timezones => _decodeRows(
      endpoint,
      decoded,
      IptvOrgTimezone._fromJson,
    ),
    IptvOrgEndpoint.blocklist => _decodeRows(
      endpoint,
      decoded,
      IptvOrgBlocklistEntry._fromJson,
    ),
  };
}

List<T> _decodeRows<T>(
  IptvOrgEndpoint endpoint,
  Object? decoded,
  _IptvOrgRowFactory<T> factory,
) {
  if (decoded is! List<Object?>) {
    throw IptvOrgSchemaException(
      endpoint: endpoint,
      index: -1,
      field: r'$',
      expected: 'array',
      actual: decoded,
    );
  }
  return List<T>.unmodifiable([
    for (var index = 0; index < decoded.length; index++)
      factory(
        _rowMap(endpoint, index, decoded[index]),
        _RowReader(endpoint, index, _rowMap(endpoint, index, decoded[index])),
      ),
  ]);
}

Map<String, Object?> _rowMap(
  IptvOrgEndpoint endpoint,
  int index,
  Object? value,
) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  throw IptvOrgSchemaException(
    endpoint: endpoint,
    index: index,
    field: r'$',
    expected: 'object',
    actual: value,
  );
}

final class _RowReader {
  const _RowReader(this.endpoint, this.index, this.json);

  final IptvOrgEndpoint endpoint;
  final int index;
  final Map<String, Object?> json;

  Never _invalid(String field, String expected, Object? actual) {
    throw IptvOrgSchemaException(
      endpoint: endpoint,
      index: index,
      field: field,
      expected: expected,
      actual: actual,
    );
  }

  String string(String field) {
    final value = json[field];
    return value is String ? value : _invalid(field, 'string', value);
  }

  String? nullableString(String field) {
    final value = json[field];
    if (value == null) return null;
    return value is String ? value : _invalid(field, 'string or null', value);
  }

  bool boolean(String field) {
    final value = json[field];
    return value is bool ? value : _invalid(field, 'boolean', value);
  }

  int integer(String field) {
    final value = json[field];
    return value is int ? value : _invalid(field, 'integer', value);
  }

  List<String> strings(String field) {
    final value = json[field];
    if (value is! List) return _invalid(field, 'string array', value);
    final result = <String>[];
    for (var itemIndex = 0; itemIndex < value.length; itemIndex++) {
      final item = value[itemIndex];
      if (item is! String) {
        return _invalid('$field[$itemIndex]', 'string', item);
      }
      result.add(item);
    }
    return List.unmodifiable(result);
  }

  List<Map<String, Object?>> maps(String field) {
    final value = json[field];
    if (value is! List) return _invalid(field, 'object array', value);
    return List.unmodifiable([
      for (var itemIndex = 0; itemIndex < value.length; itemIndex++)
        _rowMap(endpoint, index, value[itemIndex]),
    ]);
  }
}

final class IptvOrgChannel {
  const IptvOrgChannel({
    required this.id,
    required this.name,
    required this.altNames,
    required this.network,
    required this.owners,
    required this.country,
    required this.categories,
    required this.isNsfw,
    required this.launched,
    required this.closed,
    required this.replacedBy,
    required this.website,
  });

  factory IptvOrgChannel._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgChannel(
        id: row.string('id'),
        name: row.string('name'),
        altNames: row.strings('alt_names'),
        network: row.nullableString('network'),
        owners: row.strings('owners'),
        country: row.string('country'),
        categories: row.strings('categories'),
        isNsfw: row.boolean('is_nsfw'),
        launched: row.nullableString('launched'),
        closed: row.nullableString('closed'),
        replacedBy: row.nullableString('replaced_by'),
        website: row.nullableString('website'),
      );

  final String id;
  final String name;
  final List<String> altNames;
  final String? network;
  final List<String> owners;
  final String country;
  final List<String> categories;
  final bool isNsfw;
  final String? launched;
  final String? closed;
  final String? replacedBy;
  final String? website;
}

final class IptvOrgFeed {
  const IptvOrgFeed({
    required this.channel,
    required this.id,
    required this.name,
    required this.altNames,
    required this.isMain,
    required this.broadcastArea,
    required this.timezones,
    required this.languages,
    required this.format,
  });

  factory IptvOrgFeed._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgFeed(
        channel: row.string('channel'),
        id: row.string('id'),
        name: row.string('name'),
        altNames: row.strings('alt_names'),
        isMain: row.boolean('is_main'),
        broadcastArea: row.strings('broadcast_area'),
        timezones: row.strings('timezones'),
        languages: row.strings('languages'),
        format: row.string('format'),
      );

  final String channel;
  final String id;
  final String name;
  final List<String> altNames;
  final bool isMain;
  final List<String> broadcastArea;
  final List<String> timezones;
  final List<String> languages;
  final String format;
}

final class IptvOrgLogo {
  const IptvOrgLogo({
    required this.channel,
    required this.feed,
    required this.inUse,
    required this.tags,
    required this.width,
    required this.height,
    required this.format,
    required this.url,
  });

  factory IptvOrgLogo._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgLogo(
        channel: row.string('channel'),
        feed: row.nullableString('feed'),
        inUse: row.boolean('in_use'),
        tags: row.strings('tags'),
        width: row.integer('width'),
        height: row.integer('height'),
        format: row.nullableString('format'),
        url: row.string('url'),
      );

  final String channel;
  final String? feed;
  final bool inUse;
  final List<String> tags;
  final int width;
  final int height;
  final String? format;
  final String url;
}

final class IptvOrgStream {
  const IptvOrgStream({
    required this.channel,
    required this.feed,
    required this.title,
    required this.url,
    required this.referrer,
    required this.userAgent,
    required this.quality,
    required this.label,
  });

  factory IptvOrgStream._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgStream(
        channel: row.nullableString('channel'),
        feed: row.nullableString('feed'),
        title: row.string('title'),
        url: row.string('url'),
        referrer: row.nullableString('referrer'),
        userAgent: row.nullableString('user_agent'),
        quality: row.nullableString('quality'),
        label: row.nullableString('label'),
      );

  final String? channel;
  final String? feed;
  final String title;
  final String url;
  final String? referrer;
  final String? userAgent;
  final String? quality;
  final String? label;
}

final class IptvOrgGuideSource {
  const IptvOrgGuideSource({
    required this.host,
    required this.url,
    required this.format,
  });

  factory IptvOrgGuideSource._fromJson(
    Map<String, Object?> json,
    IptvOrgEndpoint endpoint,
    int index,
  ) {
    final row = _RowReader(endpoint, index, json);
    return IptvOrgGuideSource(
      host: row.string('host'),
      url: row.string('url'),
      format: row.string('format'),
    );
  }

  final String host;
  final String url;
  final String format;
}

final class IptvOrgGuide {
  const IptvOrgGuide({
    required this.channel,
    required this.feed,
    required this.site,
    required this.siteId,
    required this.siteName,
    required this.lang,
    required this.sources,
  });

  factory IptvOrgGuide._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgGuide(
        channel: row.nullableString('channel'),
        feed: row.nullableString('feed'),
        site: row.string('site'),
        siteId: row.string('site_id'),
        siteName: row.string('site_name'),
        lang: row.string('lang'),
        sources: List.unmodifiable([
          for (final source in row.maps('sources'))
            IptvOrgGuideSource._fromJson(source, row.endpoint, row.index),
        ]),
      );

  final String? channel;
  final String? feed;
  final String site;
  final String siteId;
  final String siteName;
  final String lang;
  final List<IptvOrgGuideSource> sources;
}

final class IptvOrgCategory {
  const IptvOrgCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  factory IptvOrgCategory._fromJson(
    Map<String, Object?> json,
    _RowReader row,
  ) => IptvOrgCategory(
    id: row.string('id'),
    name: row.string('name'),
    description: row.string('description'),
  );

  final String id;
  final String name;
  final String description;
}

final class IptvOrgLanguage {
  const IptvOrgLanguage({required this.name, required this.code});

  factory IptvOrgLanguage._fromJson(
    Map<String, Object?> json,
    _RowReader row,
  ) => IptvOrgLanguage(name: row.string('name'), code: row.string('code'));

  final String name;
  final String code;
}

final class IptvOrgCountry {
  const IptvOrgCountry({
    required this.name,
    required this.code,
    required this.languages,
    required this.flag,
  });

  factory IptvOrgCountry._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgCountry(
        name: row.string('name'),
        code: row.string('code'),
        languages: row.strings('languages'),
        flag: row.string('flag'),
      );

  final String name;
  final String code;
  final List<String> languages;
  final String flag;
}

final class IptvOrgSubdivision {
  const IptvOrgSubdivision({
    required this.country,
    required this.name,
    required this.code,
    required this.parent,
  });

  factory IptvOrgSubdivision._fromJson(
    Map<String, Object?> json,
    _RowReader row,
  ) => IptvOrgSubdivision(
    country: row.string('country'),
    name: row.string('name'),
    code: row.string('code'),
    parent: row.nullableString('parent'),
  );

  final String country;
  final String name;
  final String code;
  final String? parent;
}

final class IptvOrgCity {
  const IptvOrgCity({
    required this.country,
    required this.subdivision,
    required this.name,
    required this.code,
    required this.wikidataId,
  });

  factory IptvOrgCity._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgCity(
        country: row.string('country'),
        subdivision: row.nullableString('subdivision'),
        name: row.string('name'),
        code: row.string('code'),
        wikidataId: row.string('wikidata_id'),
      );

  final String country;
  final String? subdivision;
  final String name;
  final String code;
  final String wikidataId;
}

final class IptvOrgRegion {
  const IptvOrgRegion({
    required this.code,
    required this.name,
    required this.countries,
  });

  factory IptvOrgRegion._fromJson(Map<String, Object?> json, _RowReader row) =>
      IptvOrgRegion(
        code: row.string('code'),
        name: row.string('name'),
        countries: row.strings('countries'),
      );

  final String code;
  final String name;
  final List<String> countries;
}

final class IptvOrgTimezone {
  const IptvOrgTimezone({
    required this.id,
    required this.utcOffset,
    required this.countries,
  });

  factory IptvOrgTimezone._fromJson(
    Map<String, Object?> json,
    _RowReader row,
  ) => IptvOrgTimezone(
    id: row.string('id'),
    utcOffset: row.string('utc_offset'),
    countries: row.strings('countries'),
  );

  final String id;
  final String utcOffset;
  final List<String> countries;
}

enum IptvOrgBlockReason { dmca, nsfw, unknown }

final class IptvOrgBlocklistEntry {
  const IptvOrgBlocklistEntry({
    required this.channel,
    required this.reason,
    required this.rawReason,
    required this.ref,
  });

  factory IptvOrgBlocklistEntry._fromJson(
    Map<String, Object?> json,
    _RowReader row,
  ) {
    final rawReason = row.string('reason');
    return IptvOrgBlocklistEntry(
      channel: row.string('channel'),
      reason: switch (rawReason) {
        'dmca' => IptvOrgBlockReason.dmca,
        'nsfw' => IptvOrgBlockReason.nsfw,
        _ => IptvOrgBlockReason.unknown,
      },
      rawReason: rawReason,
      ref: row.string('ref'),
    );
  }

  final String channel;
  final IptvOrgBlockReason reason;
  final String rawReason;
  final String ref;
}

/// One coherent set of the thirteen API collections.
final class IptvOrgSnapshot {
  IptvOrgSnapshot({
    required List<IptvOrgChannel> channels,
    required List<IptvOrgFeed> feeds,
    required List<IptvOrgLogo> logos,
    required List<IptvOrgStream> streams,
    required List<IptvOrgGuide> guides,
    required List<IptvOrgCategory> categories,
    required List<IptvOrgLanguage> languages,
    required List<IptvOrgCountry> countries,
    required List<IptvOrgSubdivision> subdivisions,
    required List<IptvOrgCity> cities,
    required List<IptvOrgRegion> regions,
    required List<IptvOrgTimezone> timezones,
    required List<IptvOrgBlocklistEntry> blocklist,
  }) : channels = UnmodifiableListView(channels),
       feeds = UnmodifiableListView(feeds),
       logos = UnmodifiableListView(logos),
       streams = UnmodifiableListView(streams),
       guides = UnmodifiableListView(guides),
       categories = UnmodifiableListView(categories),
       languages = UnmodifiableListView(languages),
       countries = UnmodifiableListView(countries),
       subdivisions = UnmodifiableListView(subdivisions),
       cities = UnmodifiableListView(cities),
       regions = UnmodifiableListView(regions),
       timezones = UnmodifiableListView(timezones),
       blocklist = UnmodifiableListView(blocklist);

  final List<IptvOrgChannel> channels;
  final List<IptvOrgFeed> feeds;
  final List<IptvOrgLogo> logos;
  final List<IptvOrgStream> streams;
  final List<IptvOrgGuide> guides;
  final List<IptvOrgCategory> categories;
  final List<IptvOrgLanguage> languages;
  final List<IptvOrgCountry> countries;
  final List<IptvOrgSubdivision> subdivisions;
  final List<IptvOrgCity> cities;
  final List<IptvOrgRegion> regions;
  final List<IptvOrgTimezone> timezones;
  final List<IptvOrgBlocklistEntry> blocklist;
}
