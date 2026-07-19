import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  late CanonicalChannelDatabase db;
  late CanonicalChannelRepository repository;

  setUp(() {
    db = CanonicalChannelDatabase.forTesting();
    repository = CanonicalChannelRepository(db);
  });

  tearDown(() async {
    await repository.close();
  });

  CanonicalChannelsCompanion canonical({
    required String id,
    required String displayName,
    required String normalizedName,
  }) {
    final now = DateTime.utc(2026, 7, 19);
    return CanonicalChannelsCompanion.insert(
      canonicalChannelId: id,
      displayName: displayName,
      normalizedName: normalizedName,
      createdAt: now,
      updatedAt: now,
    );
  }

  ProviderChannelAliasesCompanion alias({
    required String sourceId,
    required String providerChannelId,
    String? canonicalChannelId,
    int? tvgId,
  }) {
    return ProviderChannelAliasesCompanion.insert(
      sourceId: sourceId,
      providerChannelId: providerChannelId,
      canonicalChannelId: Value(canonicalChannelId),
      providerName: 'BBC One HD',
      normalizedProviderName: 'bbc one',
      tvgId: Value(tvgId),
      streamUrlFingerprint: 'fp-$sourceId-$providerChannelId',
    );
  }

  test('upsertCanonical then getCanonical round-trips', () async {
    await repository.upsertCanonical(
      canonical(id: 'c1', displayName: 'BBC One', normalizedName: 'bbc one'),
    );

    final result = await repository.getCanonical('c1');

    expect(result?.displayName, 'BBC One');
    expect(result?.normalizedName, 'bbc one');
  });

  test('getCanonical returns null when nothing was stored', () async {
    final result = await repository.getCanonical('missing');

    expect(result, isNull);
  });

  test('upsertCanonical on the same id overwrites the previous row', () async {
    await repository.upsertCanonical(
      canonical(id: 'c1', displayName: 'BBC One', normalizedName: 'bbc one'),
    );
    await repository.upsertCanonical(
      canonical(
        id: 'c1',
        displayName: 'BBC One Updated',
        normalizedName: 'bbc one',
      ),
    );

    final result = await repository.getCanonical('c1');

    expect(result?.displayName, 'BBC One Updated');
    final all = await repository.listCanonical();
    expect(all, hasLength(1));
  });

  test('upsertAlias then aliasFor round-trips', () async {
    await repository.upsertAlias(
      alias(sourceId: 'provider-a', providerChannelId: 'a1', tvgId: 101),
    );

    final result = await repository.aliasFor(
      sourceId: 'provider-a',
      providerChannelId: 'a1',
    );

    expect(result?.tvgId, 101);
    expect(result?.providerName, 'BBC One HD');
  });

  test(
    'aliasFor returns null when nothing matches the composite key',
    () async {
      await repository.upsertAlias(
        alias(sourceId: 'provider-a', providerChannelId: 'a1'),
      );

      final result = await repository.aliasFor(
        sourceId: 'provider-b',
        providerChannelId: 'a1',
      );

      expect(result, isNull);
    },
  );

  test(
    'aliasesForCanonical returns every alias pointing at a canonical id',
    () async {
      await repository.upsertCanonical(
        canonical(id: 'c1', displayName: 'BBC One', normalizedName: 'bbc one'),
      );
      await repository.upsertAlias(
        alias(
          sourceId: 'provider-a',
          providerChannelId: 'a1',
          canonicalChannelId: 'c1',
        ),
      );
      await repository.upsertAlias(
        alias(
          sourceId: 'provider-b',
          providerChannelId: 'b1',
          canonicalChannelId: 'c1',
        ),
      );
      await repository.upsertAlias(
        alias(sourceId: 'provider-c', providerChannelId: 'c1'),
      );

      final aliases = await repository.aliasesForCanonical('c1');

      expect(aliases, hasLength(2));
      expect(aliases.map((a) => a.providerChannelId).toSet(), {'a1', 'b1'});
    },
  );

  test('aliasesByTvgId finds aliases across different providers', () async {
    await repository.upsertAlias(
      alias(sourceId: 'provider-a', providerChannelId: 'a1', tvgId: 101),
    );
    await repository.upsertAlias(
      alias(sourceId: 'provider-b', providerChannelId: 'b1', tvgId: 101),
    );
    await repository.upsertAlias(
      alias(sourceId: 'provider-c', providerChannelId: 'c1', tvgId: 202),
    );

    final matches = await repository.aliasesByTvgId(101);

    expect(matches, hasLength(2));
    expect(matches.map((a) => a.sourceId).toSet(), {
      'provider-a',
      'provider-b',
    });
  });
}
