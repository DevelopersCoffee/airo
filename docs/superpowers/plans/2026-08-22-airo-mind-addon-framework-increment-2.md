# Airo Mind Add-on Framework — Increment 2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans for later increments.

**Goal:** Ship encrypted LifeTrack destination storage, transactional plaintext migration, idempotent effect records, and `secure_destination_unavailable` read-only fallback.

**Architecture:** `SqfliteEncryptedDatabase` gates a separate `life_track_secure.db` behind `EncryptionKeyManager`. `SecureLifeTrackDestination` routes writes to encrypted storage and reads from encrypted (post-migration) or plaintext compatibility. `LifeTrackIdempotencyStore` implements `IdempotentEffectPort` for confirmation redemption.

**Verification:**
```bash
cd packages/core_data && flutter test test/storage/secure_life_track_destination_test.dart test/storage/life_track_local_data_source_test.dart
cd packages/core_domain && flutter test test/effects/
```

**Next:** Increment 3 — migrate Diet Plan through the add-on registry.
