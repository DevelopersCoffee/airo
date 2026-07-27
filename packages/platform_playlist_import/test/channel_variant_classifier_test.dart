import 'dart:convert';
import 'dart:io';

import 'package:core_native/core_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';

void main() {
  const classifier = ChannelVariantClassifier();

  test('matches the repository shared canonical golden fixture', () {
    final fixture =
        jsonDecode(
              File(
                '../../fixtures/channel_variant_cases.json',
              ).readAsStringSync(),
            )
            as Map<String, Object?>;
    final cases = fixture['canonicalCases']! as List<dynamic>;
    for (final raw in cases) {
      final value = (raw as Map<String, dynamic>);
      expect(
        classifier.canonicalName(value['input'] as String),
        value['expected'],
        reason: value['input'] as String,
      );
    }
  });

  NativeM3uEntry entry(
    String name,
    String url, {
    String? country = 'IN',
    String? language = 'hi',
    String? tvgId,
    String? group = 'Entertainment',
    Map<String, String> extras = const {},
  }) => NativeM3uEntry(
    name: name,
    url: url,
    tvgId: tvgId,
    language: language,
    group: group,
    extras: {'tvg-country': ?country, ...extras},
  );

  test('recognizes messy quality variants within the same scope', () {
    final variants = [
      entry('Sony SAB', 'https://one.example/live', tvgId: 'SonySAB.in'),
      entry('SONY SAB HD', 'https://two.example/live', tvgId: 'SonySAB.in'),
      entry(
        'Sony Sab (1080p)',
        'https://three.example/live',
        tvgId: 'SonySAB.in',
      ),
      entry('SonySAB-IN', 'https://four.example/live', tvgId: 'SonySAB.in'),
    ];

    final merged = classifier.merge(variants);

    expect(merged, hasLength(1));
    expect(merged.single.streamSources, hasLength(4));
    expect(merged.single.provenance, ChannelImportProvenance.matched);
  });

  test('keeps equal names in different country scopes distinct', () {
    final merged = classifier.merge([
      entry('News One HD', 'https://in.example/live'),
      entry(
        'News One',
        'https://gb.example/live',
        country: 'GB',
        language: 'en',
      ),
    ]);

    expect(merged, hasLength(2));
  });

  test('distinguishes duplicate URLs from separately identified feeds', () {
    final first = entry(
      'News One',
      'https://one.example/live',
      tvgId: 'NewsOne.in',
      extras: const {'feed-id': 'main'},
    );
    final duplicate = entry(
      'News One HD',
      'https://one.example/live',
      tvgId: 'NewsOne.in',
      extras: const {'feed-id': 'main'},
    );
    final regionalFeed = entry(
      'News One',
      'https://regional.example/live',
      tvgId: 'NewsOne.in',
      extras: const {'feed-id': 'south'},
    );

    expect(
      classifier.classify(first, duplicate),
      ChannelVariantRelationship.duplicate,
    );
    expect(
      classifier.classify(first, regionalFeed),
      ChannelVariantRelationship.variant,
    );
  });

  test(
    'joins an unmatched spelling to one upstream identity conservatively',
    () {
      final merged = classifier.merge([
        entry('Sony SAB HD', 'https://byoc.example/live'),
        entry('Sony SAB', 'https://upstream.example/live', tvgId: 'SonySAB.in'),
      ]);

      expect(merged, hasLength(1));
      expect(merged.single.provenance, ChannelImportProvenance.matched);
      expect(merged.single.streamSources, hasLength(2));
    },
  );

  test('does not merge two conflicting upstream identities', () {
    final merged = classifier.merge([
      entry('News One', 'https://one.example/live', tvgId: 'NewsOne.in'),
      entry('News One HD', 'https://two.example/live', tvgId: 'NewsTwo.in'),
    ]);

    expect(merged, hasLength(2));
  });

  test(
    'preserves unmatched metadata and uses stable source-independent id',
    () {
      final first = classifier.merge([
        entry('Mystery ++', 'https://slow.example/live', group: 'Odd Group'),
        entry(
          'Mystery HD',
          'https://fast.example/live',
          group: 'Odd Group',
          extras: const {'airo-health': 'available'},
        ),
      ]).single;
      final reordered = classifier.merge([
        entry(
          'Mystery HD',
          'https://fast.example/live',
          group: 'Odd Group',
          extras: const {'airo-health': 'available'},
        ),
        entry('Mystery ++', 'https://slow.example/live', group: 'Odd Group'),
      ]).single;

      expect(first.id, reordered.id);
      expect(first.group, 'Odd Group');
      expect(first.provenance, ChannelImportProvenance.unmatched);
      expect(first.streamUrl, 'https://fast.example/live');
      expect(first.streamSources, hasLength(2));
    },
  );

  test('health and quality tie-breakers order retained sources', () {
    final merged = classifier.merge([
      entry(
        'Sports One HD',
        'https://dead.example/live',
        extras: const {'airo-health': 'unavailable', 'height': '1080'},
      ),
      entry(
        'Sports One SD',
        'https://live.example/live',
        extras: const {
          'airo-health': 'available',
          'height': '576',
          'fps': '50',
        },
      ),
      entry(
        'Sports One FHD',
        'https://unchecked.example/live',
        extras: const {'height': '1080'},
      ),
    ]).single;

    expect(merged.streamSources.map((source) => source.url), [
      'https://live.example/live',
      'https://unchecked.example/live',
      'https://dead.example/live',
    ]);
  });

  test('dead-only channel remains present and flagged unavailable', () {
    final merged = classifier.merge([
      entry(
        'Dead One',
        'https://dead.example/live',
        extras: const {'airo-health': 'unavailable'},
      ),
    ]).single;

    expect(merged.isWorking, isFalse);
    expect(merged.streamSources.single.health, ChannelSourceHealth.unavailable);
  });
}
