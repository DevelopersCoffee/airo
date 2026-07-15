import 'dart:async';

/// Stable identifiers for gated product features.
///
/// `stableId` values are persisted (analytics, remote config, future billing
/// SKUs) and must never change once shipped.
enum ProFeature {
  /// Import-time dedup, canonical channel matching, dead-link pruning.
  importIntelligence('import_intelligence'),

  /// Region-ranked "Top 50" rows and curated ordering.
  regionalRanking('regional_ranking'),

  /// Program guide with local event reminders.
  epgReminders('epg_reminders'),

  /// Poster/synopsis enrichment on program detail screens.
  metadataEnrichment('metadata_enrichment'),

  /// Fixture-based live sports rows and reminders.
  sportsDesk('sports_desk'),

  /// Automatic failover across duplicate stream sources of one channel.
  multiSourceFailover('multi_source_failover');

  const ProFeature(this.stableId);

  final String stableId;
}

/// Read-side entitlement contract consumed by feature code.
///
/// Feature code must gate through [isEnabled] and never assume a concrete
/// implementation. Swapping the implementation is how the product moves from
/// "everything free" to paid tiers without touching call sites.
abstract interface class Entitlements {
  /// Whether [feature] is currently available to this install.
  bool isEnabled(ProFeature feature);

  /// Emits the full entitled set whenever it changes (e.g. after a purchase
  /// or a remote-config update). Implementations may emit an initial value.
  Stream<Set<ProFeature>> get changes;
}

/// Launch-phase policy: every pro feature is enabled for everyone.
///
/// This is the only [Entitlements] implementation shipped in the open-source
/// repository. A billing-backed implementation (Play Billing / StoreKit)
/// replaces it in the pro overlay when charging begins.
class LaunchPromoEntitlements implements Entitlements {
  const LaunchPromoEntitlements();

  @override
  bool isEnabled(ProFeature feature) => true;

  @override
  Stream<Set<ProFeature>> get changes =>
      Stream<Set<ProFeature>>.value(Set<ProFeature>.unmodifiable(
        ProFeature.values.toSet(),
      ));
}

/// Deny-all implementation for tests and lite builds.
class NoEntitlements implements Entitlements {
  const NoEntitlements();

  @override
  bool isEnabled(ProFeature feature) => false;

  @override
  Stream<Set<ProFeature>> get changes =>
      Stream<Set<ProFeature>>.value(const <ProFeature>{});
}
