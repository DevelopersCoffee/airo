# Airo License Framework — Implementation Plan

Status: **decisions locked** (2026-09-28). Phase 0 overlay sync is merged
(`airo-pro` #57, `UPSTREAM_PIN=495f1bf5`). Phase 1 is this documentation plus
mock-only `packages/airo_license`. Hosted API, RevenueCat, and Supabase are
**not** in this phase. Anonymous hosted analytics for OSS installs remain
deferred pending a privacy and Play Data Safety review.

Owners (council): Chief Cloud Officer (primary), Chief Security Officer,
Chief Architect, Chief Open Source Officer, Product Manager. Aika Stream
application wiring is application-layer; the SDK and API are framework.

Related: [OPEN_CORE.md](../OPEN_CORE.md),
[open-source-boundary.md](../open-source-boundary.md),
[first-library-decision.md](../first-library-decision.md),
`packages/core_entitlements`, `packages/airo_pro_bootstrap`, private overlay
`DevelopersCoffee/airo-pro`.

---

## 1. Existing architecture findings

### 1.1 Repository layout

| Surface | Location | Role |
|---|---|---|
| Public product | `DevelopersCoffee/airo` | Melos / pub workspace. `app/` flavors (`main.dart`, `main_tv.dart`, `main_coins.dart`, `main_mind.dart`, …). Framework under `packages/`. |
| Private overlay | `DevelopersCoffee/airo-pro` | Mirror + `packages_pro/*`. Swaps `airo_pro_bootstrap` via `pubspec_overrides.yaml`. |
| Play AAB | public `airo` | Must build without overlay. |

There is **no** RevenueCat / `purchases_flutter` dependency anywhere in
public `airo`. There is **no** Supabase client, `supabase/` directory, or
Edge Function tree. There is **no** in-app purchase flow in Aika Stream
today. TV Data Safety currently declares **no purchases**
([AIKA_STREAM_DATA_SAFETY.md](../release/AIKA_STREAM_DATA_SAFETY.md)).

### 1.2 Entitlements already shipped (do not duplicate)

Public `packages/core_entitlements`:

- `ProFeature` stable ids (frozen in
  `packages/core_entitlements/test/goldens/pro_feature_stable_ids.dart`):
  `import_intelligence`, `regional_ranking`, `epg_reminders`,
  `metadata_enrichment`, `sports_desk`, `multi_source_failover`,
  `coin_encrypted_backup_restore`, `source_connection_diagnostics`,
  `mind_indic_intelligence`.
- `Entitlements` (`isEnabled`, `changes`).
- `LaunchPromoEntitlements` (all on) — tests / overlay promo only.
- `NoEntitlements` (all off) — **Play default after PR #2063**.
- `ProModule` / `ProModuleRegistry`.

Public `packages/airo_pro_bootstrap` (no-op):

- `createEntitlements() => NoEntitlements()`
- `prepareProEntitlements()` empty
- `createProviderOverrides()` empty
- `registerProModules()` empty

App entrypoints call `prepareProEntitlements()` then
`createEntitlements()` / `createProviderOverrides()`.

Overlay (merged #54–#56, **not yet synced to public #2063 SHA**):

- `BillingEntitlementProvider` — licensed if stored token
  (`airo_pro.license_token`), `AIRO_PRO_LICENSE=true`, or grandfather
  cutoff (default Unix epoch = no silent Pro).
- `activateProLicense` / `clearProLicense` / `hasStoredProLicense`.
- Provider overrides for EPG notification gateway, canonical remaps,
  multi-source failover, TV source diagnostics.
- Modules: `pro_import_intelligence`, `pro_epg`, `pro_source_diagnostics`.
  `pro_sports` exists; ranking / metadata / Coin backup / Indic packs are
  **not fully extracted**.

**Implication:** Airo License does not replace `Entitlements`. It becomes
the **policy source**. Overlay `createEntitlements()` maps signed license
capabilities → `ProFeature`. Public Play stays `NoEntitlements` unless a
hosted free license later grants a subset (none, by policy).

### 1.3 Identity, pairing, capabilities that must not be conflated

| Package | What it is | License relation |
|---|---|---|
| `core_auth` | Firebase / Google / Apple / **enterprise** principals, email, sessions | **Out of license.** License is accountless. Do not call `AiroIdentity` for Pro. |
| `core_device_identity` + `core_pairing` | Play Anywhere node identity, playback tickets. Status: **pre-wired, unused** (#1675) | Different trust domain. License pairing is a **new** protocol. Do not reuse those models as license credentials. |
| `product_capabilities` | Device/profile **hardware** ads (TV shells, store listings) | Not license capabilities. Keep names distinct (`LicenseCapability` vs `ProductCapabilityAdvertisement`). |
| `core_data` `FlutterSecureStore` | Keystore / Keychain / libsecret | Reuse via adapter inside the app; **do not** make a pub.dev SDK depend on `core_data`. |
| `core_analytics` | App analytics wrapper | Keep separate from `license_events`. |
| `platform_coin_vault` | Key manager + secure storage | Pattern to copy, not a dependency of `airo_license`. |

### 1.4 Open-source publishing today

- Almost every package has `publish_to: none`.
- Pilot pub.dev package is `dpad_qualification` (extracted repo), not the
  monorepo.
- [open-source-boundary.md](../open-source-boundary.md) currently lists
  **commercial entitlement logic as private**. This plan **narrows** that:
  reusable **contracts + client SDK** are public; Aika SKUs, overlay
  modules, service-role keys, webhook secrets, production schema URLs
  remain private.

### 1.5 Conflicts with the proposed architecture

1. **Local-first vs central registration.** Public Aika is local-first;
   TV privacy copy says playlist/IDs stay on device. Registering every
   Play install with Supabase is a product and Data Safety change.
2. **Play AAB vs RevenueCat.** Putting `purchases_flutter` in public
   `app/pubspec.yaml` / `pubspec_tv.yaml` forces IAP + new Data Safety
   answers on the **open** store listing. Overlay-only purchases avoid
   that.
3. **Overlay pin lag.** `airo-pro` `UPSTREAM_PIN` is still pre-#2063.
   Licensed Pro cannot call `prepareProEntitlements()` until sync.
4. **Local license token vs RevenueCat.** Overlay #56 is a SharedPreferences
   token, not a store purchase. Must be a documented migration, not two
   sources of truth.
5. **Spec example capabilities** (`multiview`, `picture_in_picture`, …)
   are **not** current Aika Pro features. Do not invent them in v1.
6. **`core_auth` enterprise** is login-shaped. Seat/SSO “enterprise
   management” is **out of v1**. Installation/license management is in.
7. **Web identity.** `flutter_secure_storage` on web is weaker; clearing
   site data **replaces** the installation. Spec already requires this.

### 1.6 Tests and CI

- Entitlement unit tests: `packages/core_entitlements/test/`.
- Bootstrap contract: `packages/airo_pro_bootstrap/test/`.
- Overlay billing tests: `packages_pro/pro_billing/test/`.
- Workspace CI: `.github/workflows/ci.yml`, `pr-checks.yml`. No license
  API jobs exist.
- GitHub Actions minutes are costed — license tests stay **package-local**
  with mocks; no production RC/Supabase in CI.

---

## 2. Proposed architecture (locked intent)

```
Play OSS (airo)                         Pro overlay (airo-pro)
────────────────                        ──────────────────────
player, playlists, EPG UI               pro_* modules
core_entitlements contracts             createProviderOverrides()
airo_pro_bootstrap no-op                airo_license + RevenueCat adapter
airo_license (optional local-free)      LicenseEntitlements adapter
                                        → Entitlements.isEnabled(ProFeature)

                Airo License SDK (public, reusable)
                              |
                              v
                Airo License API (hosted)
                     |              |
                     v              v
               RevenueCat      Postgres (Supabase first)
               (purchases,     (licenses, installations,
                webhooks)       policies, events)
```

**Final architecture decision (from product):** RevenueCat + Postgres +
Airo License API + reusable Flutter SDK. Default license: **free**.
`max_devices`: **-1**. Installation tracking: **enabled on the API**.
User login: **disabled**. Personal user data: **not collected**.

**Open-core split (from prior work):**

| Public (`airo`) | Private (`airo-pro`) |
|---|---|
| Player, import, exact-id remaps, search, single-source play, EPG grid | Canonical remaps, OS EPG reminders, failover, source diagnostics, ranking/metadata/sports when extracted |
| `airo_license` client (no secrets, no Aika SKUs) | RevenueCat adapter, Aika `product_id` mapping, checkout/restore UI, overlay modules |
| Example SQL / OpenAPI (no production URLs) | Production Edge Functions, service role, webhook auth |
| `NoEntitlements` until overlay / hosted policy says otherwise | `LicenseEntitlements` after verified purchase or signed cache |

Flutter **never** writes license rows. Clients call the API. RLS denies
direct table writes from anon keys.

Backend stays behind a repository port (`LicenseStore`) so Postgres can
move off Supabase later without changing the SDK.

---

## 3. Package and repo layout

Adapt the requested `airo_license/` tree to Melos conventions.

### 3.1 Public, intended for pub.dev (after a stability cut)

`packages/airo_license/` — **zero** dependency on `app`, `feature_iptv`,
`core_auth`, RevenueCat, Supabase Flutter.

```
packages/airo_license/
  lib/airo_license.dart
  lib/src/
    core/          # License, EntitlementTier, Installation, LicenseStatus,
                   # DevicePolicy, LicenseCapability
    identity/      # InstallationIdentity, KeyManager (interfaces)
    providers/     # PurchaseProvider (interface only)
    storage/       # SecureStorage + LicenseCache interfaces
    api/           # LicenseClient (HTTP), signed LicenseSnapshot
    services/      # LicenseService, InstallationService, EntitlementService
    models/
    exceptions/
  example/         # tiny Dart CLI or Flutter demo with FakeLicenseApi
  test/
  module.yaml
  pubspec.yaml     # publishable metadata; keep publish_to: none until cut
```

No `AiroLicense.instance` global required in the library. Prefer
constructible `LicenseService` + optional facade for Aika. Avoid a second
service locator next to Riverpod.

### 3.2 Not on Play OSS (overlay or private API repo)

| Piece | Where |
|---|---|
| `RevenueCatPurchaseProvider` | `airo-pro` `packages_pro/airo_license_revenuecat` (or overlay bootstrap) |
| `LicenseEntitlements` adapter to `ProFeature` | overlay `airo_pro_bootstrap` |
| Edge Functions + SQL migrations | **private** `airo-license-api` (recommended) or `airo-pro/supabase/` |
| Aika product policies / RC entitlement `aika_pro` | API seed data, not the SDK |

A published community SDK should accept **any** `product_id` and a
`PurchaseProvider` the integrator supplies.

### 3.3 What we will not put in the SDK

- Google/Apple login
- `core_auth` `AiroIdentity`
- Hardware IDs (IMEI, MAC, serial, advertising ID)
- Viewing/playback history
- Service role key
- Direct Drift/Supabase table access from Flutter

---

## 4. Database design

Postgres (Supabase initially). Types as `text` + check constraints (or
enums) for `license_type`, `status`. UUID PKs as specified.

### 4.1 `licenses`

As specified. Unique `(product_id, license_id)`. Unique partial index on
`(provider, provider_customer_id)` where provider is RevenueCat **and**
customer id is not null — prevents duplicate paid licenses.

Free licenses: `provider = 'airo'`, `provider_customer_id` null. **Do not**
create a RevenueCat customer solely to hold a free row.

Idempotent initialize: lookup by `installation_id` first; if present,
return existing license. Never insert a second free license for the same
installation.

### 4.2 `installations`

As specified. Unique `installation_id`. FK `license_id` → `licenses`.
`platform` / `device_type` / `app_version` are coarse enums/strings
(android, android_tv, ios, web, …) — not hardware serials.

Authoritative active count:

```sql
count(*) filter (where status = 'active')
  from installations where license_id = $1
```

Activation under `max_devices >= 0` uses
`SELECT … FROM licenses WHERE id = $1 FOR UPDATE` then insert/update
installation in the same transaction.

### 4.3 `license_events`

Append-only. `metadata` JSONB allow-list (platform, app_version,
policy_version, entitlement, reason). Reject unknown keys that look like
PII (`email`, `name`, `phone`, `gps`, …) in API validation.

Retention (proposal, confirm in §18): raw events **90 days**; daily
aggregates retained **24 months**.

### 4.4 `product_policies`

As specified. Unique `(product_id, license_type, policy_version)`.

Aika seed:

| product_id | license_type | max_devices | capabilities |
|---|---|---|---|
| `aika_stream` | `free` | -1 | `{}` (no ProFeature) |
| `aika_stream` | `lifetime` / `subscription` | -1 (until product changes) | map of current `ProFeature` stable ids → true |

### 4.5 Pairing (required by §11, not in the original table list)

`license_pairing_challenges`:

- `id`, `license_id`, `code_hash`, `expires_at`, `consumed_at`,
  `requesting_installation_id`, `created_at`

Store **hashes only**. TTL on the order of minutes. Single-use.

### 4.6 Insights (do not query raw events for dashboards)

`license_daily_stats` (or materialized view refreshed daily):
installations total/active, free vs pro, platform, device_type,
app_version, upgrades, revocations. Populated by a scheduled job, not the
Flutter SDK.

### 4.7 RLS

- Enable RLS on all tables.
- Anon/authenticated roles: **no** INSERT/UPDATE/DELETE.
- Edge Functions use service role **only on the server**.
- Optional: read of own signed snapshot is via API, not PostgREST.

Indexes: `installations(license_id, status)`,
`license_events(license_id, created_at)`,
`installations(installation_id)`.

---

## 5. API design

Base: `/v1`. JSON. Idempotency-Key header on initialize, register,
restore, pair, webhook.

Authentication of installation calls: signed request
(`installation_id` + timestamp + signature with device private key) **or**
a short-lived installation JWT issued after initialize. Public key stored
on `installations`. Unsigned clients (web without WebCrypto) fall back to
installation secret in secure/web storage — document weaker web threat
model.

| Endpoint | Purpose |
|---|---|
| `POST /v1/licenses/initialize` | Create-or-return free license + installation |
| `POST /v1/licenses/status` | Refresh signed snapshot |
| `POST /v1/installations/register` | Attach install to license |
| `POST /v1/installations/heartbeat` | `last_seen_at`; does **not** auto-deactivate |
| `POST /v1/installations/deactivate` | Explicit device replacement |
| `POST /v1/licenses/restore` | RC restore → bind paid entitlement to **this** license |
| `POST /v1/licenses/verify-entitlement` | Server re-check vs RC (never trust client claim) |
| `POST /v1/licenses/pair` | Phone confirms TV code |
| `POST /v1/licenses/transfer` | v1 stub or full; see §18 |
| `POST /v1/webhooks/revenuecat` | Idempotent entitlement updates |

Responses: signed `LicenseSnapshot` (Ed25519 or equivalent maintained
library; no home-rolled crypto). Fields as specified plus
`capabilities` object and `policy_version`.

Errors distinct from revocation: `network`, `unavailable`, `expired`,
`invalid_signature`, `revoked`, `device_limit`. **HTTP 5xx / timeout ≠
revoked.** Cached last-valid snapshot remains in force until `expires_at`
or an authentic revoked snapshot.

Rate limits: initialize / register / pair / restore.

---

## 6. Security model

- Service role and `REVENUECAT_WEBHOOK_AUTH` never in Flutter /
  `--dart-define` for shipping apps.
- Webhook: authorization header as configured by RevenueCat; reject
  duplicates via `event.id` unique table.
- Client cannot set `entitlement = pro`.
- Pairing codes: CSPRNG, hashed at rest, short TTL, single use; not a
  license secret.
- Installation private key: platform secure storage; public key on server.
- No IMEI/MAC/serial/advertising ID.
- No SSL pinning in v1 (rotation risk).
- Signed snapshot verify in SDK before applying capabilities.
- Audit via `license_events` only.

Trust model for “one Pro, many devices”:

- **Same store account + restore** can attach RC customer to a license
  when the webhook/customer id matches.
- **Anonymous RC App User IDs do not** equal cross-platform ownership.
- **Pairing** is the accountless way to attach a second installation
  (TV) to a license that already has Pro.
- A client-generated `license_id` is **never** sufficient to steal Pro.

---

## 7. RevenueCat

`PurchaseProvider` in the public SDK:

- `initialize`, `getCustomerInfo`, `getEntitlements`, `restorePurchases`,
  `listenForCustomerChanges`, `verifyCurrentEntitlement` (the last is
  **informative**; server webhook / verify-entitlement is authoritative).

`RevenueCatProvider` lives in the overlay. Anonymous App User IDs only.
Do not `logIn` with email.

Mapping (Aika):

| RevenueCat | Airo |
|---|---|
| entitlement `aika_pro` | `product_id=aika_stream`, `entitlement=pro`, `license_type=lifetime` or `subscription` from product type |

Free installs: **no** RC customer required.

Handle purchase, restore, expiration, refund, revocation, entitlement
change, offline cached `CustomerInfo` (UX only).

---

## 8. Capability system vs feature flags vs ProFeature

Three layers:

1. **License capabilities** — signed JSON from `product_policies`.
   Entitlement: *may this install use X?*
2. **Feature flags** — existing rollout flags, unchanged. *Is X shipped
   in this build?*
3. **`ProFeature` / `ProModule`** — overlay implementation registration.

Aika v1 capability keys **are** the existing stable ids, e.g.
`epg_reminders`, `multi_source_failover`. Do **not** add `multiview` /
`pip` / `premium_themes` until those products exist.

Gating in app code:

```dart
entitlements.isEnabled(ProFeature.epgReminders)
```

stays. Overlay fills `Entitlements` from
`snapshot.capabilities['epg_reminders'] == true` (or nested params later).
Avoid a parallel `if (isPro)` forest. `AiroLicense.hasCapability` is the
SDK API for **other** products; Aika keeps `Entitlements` as the UI gate
so Play and Pro share one call site.

---

## 9. Offline and refresh

- First launch, no network: local **free** snapshot (unsigned or
  self-issued with `entitlement=free`), app usable.
- On connectivity: initialize/status; replace cache if signature valid.
- Refresh: heartbeat on cold start + every 24h while running (tunable).
- Revocation only from a **valid signed** snapshot or verified webhook
  pull on next status — never from transport failure.

Web: if storage is cleared, new `installation_id`; pairing/restore
required to regain Pro. Document in privacy + settings copy.

Android Auto: inherit phone session; no purchase UI in the car.

---

## 10. Aika Stream integration (application)

**Play OSS**

- Do not link RevenueCat.
- Do not ship Pro modules.
- Settings: optional “License & Pro” that states the build is the free
  open product and points to Pro download / purchase **only if** we
  decide Play talks to the API (see §18). If Play is local-only, omit
  device-count from a server and show “not linked”.

**Pro overlay**

- `prepareProEntitlements()`: secure identity → `LicenseService.initialize`
  → map snapshot → `BillingEntitlementProvider` replacement
  (`LicenseEntitlements`).
- Settings → License & Pro: plan, status, installation (redacted),
  count (informational while `max_devices=-1`), Restore, Manage devices,
  Link device (phone) / Activate (TV), Legal.
- No login page.

**Existing features:** player/playlist/guide remain; Pro gates stay
`isEnabled`. Extract remaining overlay packages in later PRs (ranking,
metadata, sports, Coin backup, Indic) — not a rewrite of Aika.

**Migration from overlay #56 token:** if `airo_pro.license_token` is set,
treat as **dev override** until RC is configured; then deprecate. Do not
keep two production unlock paths.

---

## 11. Insights

Server-side aggregates only. No new analytics SDK in v1. No viewing
history. Product analytics remains `core_analytics` and stays disconnected
from `license_id` in the client.

---

## 12. Environment

Example file `docs/airo-license/.env.example` (API repo / overlay CI),
**never** committed with values:

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_ROLE_KEY=
REVENUECAT_WEBHOOK_AUTH=
REVENUECAT_PUBLIC_SDK_KEY_ANDROID=
REVENUECAT_PUBLIC_SDK_KEY_IOS=
LICENSE_SIGNING_PRIVATE_KEY=
LICENSE_SIGNING_PUBLIC_KEY=
```

Flutter may receive **only** public API URL, snapshot public key, and
(overlay) RC public SDK keys.

---

## 13. Testing strategy

Package-local, mocked HTTP and `PurchaseProvider`.

Must cover: new free install, repeat initialize, upgrade, restore,
expiration, revocation, invalid entitlement, offline free, register,
duplicate register, heartbeat, deactivate, reinstall, unlimited vs
limited `max_devices`, concurrent activation, anonymous RC, webhook
duplicate/invalid/refund, unauthorized API, bad signature, tampered
snapshot, expired/reused pairing, client mutation attempt, web identity
reset.

No production credentials in CI.

---

## 14. Implementation phases (after §18)

| Phase | Work | Repo |
|---|---|---|
| 0 | Overlay `sync_upstream.sh` to public `main` (#2063) so Pro `prepare` runs | `airo-pro` |
| 1 | This plan + ADR + OPEN_CORE / open-source-boundary updates | `airo` |
| 2 | SQL migrations, RLS, indexes | `airo-license-api` |
| 3 | Edge Functions + webhook | `airo-license-api` |
| 4 | `packages/airo_license` + tests + example | `airo` |
| 5 | RevenueCat adapter | `airo-pro` |
| 6 | Overlay `LicenseEntitlements` + keep `ProFeature` gates | `airo-pro` |
| 7 | License settings UI (TV + phone) | `airo` hooks + overlay UI |
| 8 | Security tests, concurrency, pairing | both |
| 9 | Docs: setup, privacy inventory, integration, troubleshooting | both |

Do **not** rewrite Aika. Do **not** publish to pub.dev until the SDK is
stable and scanned (boundary checklist).

---

## 15. Migration plan (runtime)

1. Current Play: `NoEntitlements`, no license network.
2. Current Pro (post-sync, pre-RC): dart-define / stored token (dev).
3. Introduce API + free initialize (scope per §18).
4. RC webhook upgrades `entitlement`.
5. Remove production use of SharedPreferences token.
6. Optional pub.dev of `airo_license`.

Rollback: overlay can keep `NoEntitlements` / token provider behind a
flag if API is down; Play unchanged.

---

## 16. Risks

- Play Data Safety / privacy policy if OSS registers installs.
- Binary size and IAP policy if RC lands in public flavor by mistake.
- Dual unlock (token vs RC) confusion.
- Pairing UX on TV (leanback).
- Web install churn.
- GitHub Actions cost if license API tests are inlined into full CI.
- Name clash: `core_pairing` vs license pairing — document in API docs.

---

## 17. Files we expect to touch (when coding starts)

**Public `airo` (framework):** `packages/airo_license/**` (new),
`packages/airo_license/module.yaml`, root workspace `pubspec.yaml`,
`docs/OPEN_CORE.md`, `docs/open-source-boundary.md`, ADR.

**Public `airo` (app, minimal):** settings route **hook** only if Play
shows license status; `isEnabled` call sites already exist — do not
scatter `isPro`.

**Private `airo-pro`:** overlay bootstrap, `pro_billing` replacement or
wrap, RC adapter, settings screens, `UPSTREAM_PIN`.

**API repo:** migrations, functions, `.env.example`.

**Do not modify** working player/playlist/EPG paths except entitlement
gates already present.

---

## 18. Locked decisions (2026-09-28)

Product confirmed all recommendations. These are now requirements.

1. **Play OSS → hosted API: no.** Local-first free. Hosted registration
   and purchases only in Pro. Do not register every free Play
   installation. Anonymous installation analytics may be revisited later
   with an explicit privacy and Play Data Safety review.
2. **API repo:** new private `DevelopersCoffee/airo-license-api`. Public
   `airo` ships example SQL/contracts only — no production backend.
3. **pub.dev:** merge `airo_license` in-monorepo first, test, then extract
   and publish (same path as `dpad_qualification`).
4. **Supabase / RevenueCat:** not provisioned. Scaffold interfaces,
   mocks, migrations, and env placeholders. **Do not invent keys.**
5. **Play settings:** static “Free / Open Source” line only. Restore,
   device management, and TV linking stay in Pro.
6. **Pairing:** phone-authorizes-TV in v1. License transfer is a
   **documented stub**, not a half-working feature.
7. **Event retention:** 90 days raw / 24 months aggregates, with an
   explicit retention job and documented policy.
8. **`AIRO_PRO_LICENSE`:** CI/dev only. Must not become a production
   bypass or a public-build entitlement mechanism.
9. **Enterprise SSO:** out of v1. “Enterprise management” means
   installations, device limits, events, and pairing only.

Additional constraints:

- Keep the accountless license system **separate from `core_auth`**.
- v1 capability keys **are** existing `ProFeature` stable ids.
- Phase 0 (before dual-test of licensed Pro): sync `airo-pro` to public
  #2063 so `prepareProEntitlements()` runs in overlay builds.

---

## 19. Definition of done (v1)

Matches the product checklist, with the open-core constraint: Pro
implementations remain in `airo-pro`; Play remains a complete free app;
the SDK is reusable without Aika; credentials never in git; tests mock
RC/Supabase; existing Aika playback/import/guide keep working.
