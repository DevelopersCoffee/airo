import 'package:drift/drift.dart';

import 'canonical_channel_database_stub.dart'
    if (dart.library.io) 'canonical_channel_database_io.dart' as backend;

part 'canonical_channel_database.g.dart';

/// Canonical channel identities (CV-017): a normalized, user-facing channel
/// concept that provider aliases point to when confidently matched.
class CanonicalChannels extends Table {
  TextColumn get canonicalChannelId => text()();
  TextColumn get displayName => text()();
  TextColumn get normalizedName => text()();
  TextColumn get language => text().nullable()();
  TextColumn get country => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get logoFingerprint => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {canonicalChannelId};
}

/// A single provider's channel entry, optionally pointing at a canonical
/// identity once matched with sufficient confidence (CV-017). Kept separate
/// from [CanonicalChannels] per the issue's "store provider channel aliases
/// separately from user-facing canonical identities" framework rule.
@DataClassName('ProviderChannelAlias')
class ProviderChannelAliases extends Table {
  TextColumn get sourceId => text()();
  TextColumn get providerChannelId => text()();
  TextColumn get canonicalChannelId => text().nullable()();
  TextColumn get providerName => text()();
  TextColumn get normalizedProviderName => text()();
  IntColumn get tvgId => integer().nullable()();
  TextColumn get groupTitle => text().nullable()();
  TextColumn get streamUrlFingerprint => text()();
  TextColumn get resolution => text().nullable()();
  BoolColumn get isVod => boolean().withDefault(const Constant(false))();
  BoolColumn get isRadio => boolean().withDefault(const Constant(false))();
  BoolColumn get isAdult => boolean().withDefault(const Constant(false))();
  // Stored as the ChannelMatchConfidence enum's name ('high'/'medium'/
  // 'low'/'none'), not a raw double -- keeps the persisted value tied to
  // CanonicalChannelMatcher's actual confidence tiers instead of an
  // arbitrary score that could drift out of sync with matcher logic.
  TextColumn get matchConfidence => text().nullable()();

  @override
  Set<Column> get primaryKey => {sourceId, providerChannelId};
}

@DriftDatabase(tables: [CanonicalChannels, ProviderChannelAliases])
class CanonicalChannelDatabase extends _$CanonicalChannelDatabase {
  CanonicalChannelDatabase(super.executor);

  /// Opens the real on-device database file. Not used in tests -- see
  /// [CanonicalChannelDatabase.forTesting] for an in-memory instance.
  factory CanonicalChannelDatabase.open() {
    return CanonicalChannelDatabase(backend.openFileExecutor());
  }

  /// An in-memory database for tests -- never touches disk.
  factory CanonicalChannelDatabase.forTesting() {
    return CanonicalChannelDatabase(backend.memoryExecutor());
  }

  @override
  int get schemaVersion => 1;
}
