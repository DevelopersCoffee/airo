import 'package:drift/drift.dart';

import 'canonical_channel_database.dart';

/// Repository over [CanonicalChannelDatabase] -- the persistence layer for
/// CV-017's canonical channel identity / provider alias contract. Kept
/// separate from [CanonicalChannelMatcher]/[FavoriteChannelRemapper]
/// (scoring, pure) so those stay unit-testable without a database.
class CanonicalChannelRepository {
  CanonicalChannelRepository(this._db);

  final CanonicalChannelDatabase _db;

  Future<void> upsertCanonical(CanonicalChannelsCompanion channel) {
    return _db.into(_db.canonicalChannels).insertOnConflictUpdate(channel);
  }

  Future<CanonicalChannel?> getCanonical(String canonicalChannelId) {
    return (_db.select(_db.canonicalChannels)
          ..where((t) => t.canonicalChannelId.equals(canonicalChannelId)))
        .getSingleOrNull();
  }

  Future<List<CanonicalChannel>> listCanonical() {
    return _db.select(_db.canonicalChannels).get();
  }

  Future<void> upsertAlias(ProviderChannelAliasesCompanion alias) {
    return _db.into(_db.providerChannelAliases).insertOnConflictUpdate(alias);
  }

  Future<ProviderChannelAlias?> aliasFor({
    required String sourceId,
    required String providerChannelId,
  }) {
    return (_db.select(_db.providerChannelAliases)..where(
          (t) =>
              t.sourceId.equals(sourceId) &
              t.providerChannelId.equals(providerChannelId),
        ))
        .getSingleOrNull();
  }

  Future<List<ProviderChannelAlias>> aliasesForCanonical(
    String canonicalChannelId,
  ) {
    return (_db.select(
      _db.providerChannelAliases,
    )..where((t) => t.canonicalChannelId.equals(canonicalChannelId))).get();
  }

  /// Aliases sharing [tvgId], across every provider -- the same signal
  /// [CanonicalChannelMatcher] treats as a high-confidence match.
  Future<List<ProviderChannelAlias>> aliasesByTvgId(int tvgId) {
    return (_db.select(
      _db.providerChannelAliases,
    )..where((t) => t.tvgId.equals(tvgId))).get();
  }

  Future<void> close() => _db.close();
}
