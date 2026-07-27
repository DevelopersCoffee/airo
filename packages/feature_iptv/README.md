# feature_iptv

Airo's application-owned IPTV journeys, including browse, search, playback,
filters, settings, and TV presentation. Reusable transport, parsing, storage,
and player contracts remain in platform packages.

## Regional discovery curation

Regional shelves are composed by `RegionalDiscoveryComposer` from typed
channel metadata, the user's country preference, optional session health, and
reviewed editorial seeds. Labels may describe only those facts; popularity
claims are not allowed.

Seeds live in `lib/domain/regional_discovery.dart` as
`RegionalDiscoverySeed` values:

```dart
RegionalDiscoverySeed(
  countryCode: 'IN',          // ISO 3166-1 alpha-2
  title: 'Curated for India', // explicit editorial label
  channelIds: <String>[       // upstream IDs in intended shelf order
    'DDNational.in',
    'DDNews.in',
  ],
)
```

Unknown or retired IDs are ignored. Adding a country requires product review
of the label and ordered IDs plus deterministic composer tests. Device locale
provides the initial country; Airo's existing country picker is the manual,
locally persisted override. No network location signal is used.
