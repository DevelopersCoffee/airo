import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

/// Static, reviewable editorial input for a regional discovery shelf.
///
/// IDs use the upstream channel ID contract. Unknown IDs are ignored, so a
/// retired channel cannot break browse composition.
final class RegionalDiscoverySeed {
  const RegionalDiscoverySeed({
    required this.countryCode,
    required this.title,
    required this.channelIds,
  });

  final String countryCode;
  final String title;
  final List<String> channelIds;
}

/// India-first v1 editorial seed. Add another entry only after product review;
/// order is the intended shelf order and is therefore part of the config.
const regionalDiscoverySeeds = <RegionalDiscoverySeed>[
  RegionalDiscoverySeed(
    countryCode: 'IN',
    title: 'Curated for India',
    channelIds: <String>[
      'DDNational.in',
      'DDNews.in',
      'AajTak.in',
      'NDTVIndia.in',
      'SansadTV1.in',
    ],
  ),
];

/// Deterministic application policy for honest regional browse shelves.
final class RegionalDiscoveryComposer {
  const RegionalDiscoveryComposer({this.maxItems = 20});

  final int maxItems;

  List<RailResult> compose({
    required List<IPTVChannel> channels,
    required String countryCode,
    required String countryName,
    required Map<String, String> languageNames,
    Map<String, StreamAvailability> availabilityByChannelId = const {},
    List<RegionalDiscoverySeed> seeds = regionalDiscoverySeeds,
  }) {
    final normalizedCountry = countryCode.trim().toUpperCase();
    final providerIndex = <String, int>{
      for (var index = 0; index < channels.length; index++)
        channels[index].id: index,
    };
    final regional = channels
        .where(
          (channel) =>
              channel.country?.trim().toUpperCase() == normalizedCountry,
        )
        .toList(growable: false);
    final results = <RailResult>[];

    void add({
      required String id,
      required String title,
      required Iterable<IPTVChannel> candidates,
      required int priority,
      RailLayout layout = RailLayout.standard,
      String? subtitle,
      bool preserveCandidateOrder = false,
    }) {
      final selected = candidates.toList(growable: false);
      if (selected.isEmpty) return;
      final ordered = preserveCandidateOrder
          ? selected
          : _healthOrdered(selected, availabilityByChannelId, providerIndex);
      results.add(
        RailResult(
          definition: RailDefinition(
            id: id,
            title: title,
            subtitle: subtitle,
            query: const RailQuery(),
            priority: priority,
            layout: layout,
            maxItems: maxItems,
          ),
          channels: ordered.take(maxItems).toList(growable: false),
        ),
      );
    }

    add(
      id: 'regional-$normalizedCountry',
      title: 'Channels in $countryName',
      subtitle: 'From channel country metadata',
      candidates: regional,
      priority: 0,
      layout: RailLayout.hero,
    );

    final byId = {for (final channel in regional) channel.id: channel};
    final seed = seeds
        .where(
          (candidate) =>
              candidate.countryCode.toUpperCase() == normalizedCountry,
        )
        .firstOrNull;
    if (seed != null) {
      add(
        id: 'curated-$normalizedCountry',
        title: seed.title,
        subtitle: 'Editorial selection',
        candidates: [for (final id in seed.channelIds) ?byId[id]],
        priority: 10,
        preserveCandidateOrder: true,
      );
    }

    final categories = <ChannelCategory, List<IPTVChannel>>{};
    for (final channel in regional) {
      if (channel.category == ChannelCategory.all) continue;
      categories.putIfAbsent(channel.category, () => []).add(channel);
    }
    final categoryEntries = categories.entries.toList()
      ..sort((a, b) {
        final size = b.value.length.compareTo(a.value.length);
        return size != 0 ? size : a.key.name.compareTo(b.key.name);
      });
    for (final entry in categoryEntries.take(3)) {
      add(
        id: 'category-${entry.key.name}-$normalizedCountry',
        title: '${entry.key.label} · $countryName',
        subtitle: 'Category and country metadata',
        candidates: entry.value,
        priority: 20 + categoryEntries.indexOf(entry),
      );
    }

    final countryLanguages = <String, List<IPTVChannel>>{};
    for (final channel in regional) {
      for (final language in channel.languages) {
        final code = language.trim().toLowerCase();
        if (code.isNotEmpty) {
          countryLanguages.putIfAbsent(code, () => []).add(channel);
        }
      }
    }
    final languageEntries = countryLanguages.entries.toList()
      ..sort((a, b) {
        final size = b.value.length.compareTo(a.value.length);
        return size != 0 ? size : a.key.compareTo(b.key);
      });
    if (languageEntries.firstOrNull case final language?) {
      final name = languageNames[language.key] ?? language.key.toUpperCase();
      add(
        id: 'language-${language.key}-$normalizedCountry',
        title: 'In $name',
        subtitle: 'Language metadata',
        candidates: language.value,
        priority: 30,
      );
    }

    add(
      id: 'reliable-$normalizedCountry',
      title: 'Reliable now',
      subtitle: 'Available in this session’s stream check',
      candidates: regional.where(
        (channel) =>
            availabilityByChannelId[channel.id] == StreamAvailability.available,
      ),
      priority: 40,
      layout: RailLayout.compact,
    );

    results.sort(
      (a, b) => a.definition.priority.compareTo(b.definition.priority),
    );
    return List.unmodifiable(results);
  }

  List<IPTVChannel> _healthOrdered(
    List<IPTVChannel> channels,
    Map<String, StreamAvailability> availability,
    Map<String, int> providerIndex,
  ) {
    final ordered = [...channels];
    ordered.sort((a, b) {
      final health = _healthRank(
        availability[a.id],
      ).compareTo(_healthRank(availability[b.id]));
      if (health != 0) return health;
      return (providerIndex[a.id] ?? 0).compareTo(providerIndex[b.id] ?? 0);
    });
    return ordered;
  }

  int _healthRank(StreamAvailability? availability) => switch (availability) {
    StreamAvailability.available => 0,
    null || StreamAvailability.unverified => 1,
    StreamAvailability.restricted => 2,
    StreamAvailability.unavailable => 3,
    StreamAvailability.cancelled => 4,
  };
}
