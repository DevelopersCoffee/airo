/// Capability ids for Aika Stream v1. Must stay aligned with
/// `ProFeature.stableId` in `core_entitlements`.
abstract final class AikaLicenseCapabilities {
  static const importIntelligence = 'import_intelligence';
  static const regionalRanking = 'regional_ranking';
  static const epgReminders = 'epg_reminders';
  static const metadataEnrichment = 'metadata_enrichment';
  static const sportsDesk = 'sports_desk';
  static const multiSourceFailover = 'multi_source_failover';
  static const coinEncryptedBackupRestore = 'coin_encrypted_backup_restore';
  static const sourceConnectionDiagnostics = 'source_connection_diagnostics';
  static const mindIndicIntelligence = 'mind_indic_intelligence';

  static const Set<String> all = {
    importIntelligence,
    regionalRanking,
    epgReminders,
    metadataEnrichment,
    sportsDesk,
    multiSourceFailover,
    coinEncryptedBackupRestore,
    sourceConnectionDiagnostics,
    mindIndicIntelligence,
  };
}

/// Policy-issued capability map. Values are `bool` or nested maps of
/// parameters (`multiview.max_streams` later). Unknown keys are ignored.
final class LicenseCapabilities {
  const LicenseCapabilities(this._values);

  static const empty = LicenseCapabilities({});

  final Map<String, Object?> _values;

  bool has(String capabilityId) {
    final value = _values[capabilityId];
    if (value is bool) return value;
    if (value is Map) return value.isNotEmpty;
    return false;
  }

  Object? parameter(String capabilityId) => _values[capabilityId];

  Map<String, Object?> get asMap => Map<String, Object?>.unmodifiable(_values);
}
