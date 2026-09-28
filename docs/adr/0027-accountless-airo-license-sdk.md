# ADR-0027: Accountless Airo License SDK stays public; hosted commerce stays overlay

## Status

Accepted

## Date

2026-09-28

## Context

Aika Stream is splitting into a public Play/OSS product and a private Pro
overlay (`airo-pro`). We need a reusable, accountless licensing framework
(installation identity, capabilities, purchase *ports*) without turning the
open-source app into a telemetry or IAP client, and without folding license
state into `core_auth`.

Play Data Safety for the TV profile currently declares no developer-collected
user IDs and no purchases. Registering every free install with a hosted API
would change that.

## Decision

1. Public `packages/airo_license` holds contracts, a local-first
   `LocalLicenseClient`, `UnavailablePurchaseProvider`, and cache/identity
   ports. It must not depend on RevenueCat, Supabase, HTTP clients, or
   `core_auth`.
2. Hosted License API, RevenueCat, pairing, device management, restore, and
   purchase UI live in `airo-pro` plus a private `airo-license-api` repo.
3. Play OSS remains local-first: `NoEntitlements` via `airo_pro_bootstrap`,
   no hosted installation registration. Anonymous hosted analytics for OSS
   installs are deferred pending a privacy and Data Safety review.
4. v1 capability keys are the existing `ProFeature.stableId` strings.
5. `AIRO_PRO_LICENSE` remains CI/dev-only in the overlay. It is not a Play
   entitlement mechanism.
6. License transfer is a documented stub until a complete recovery design
   exists. Phone-authorizes-TV pairing is overlay/API, not this package.

## Contract Impact

| Question | Answer |
|---|---|
| Which runtime contracts change? | None in app flavors yet. New package `airo_license` is pre-wired (not on the Play graph). `Entitlements` / `ProFeature` remain the Aika UI gate. |
| Which conformance tests become invalid? | None. Overlay bootstrap tests still own licensed vs deny-all mapping. |
| Which benchmarks must be re-run? | None. |
| Which review roles must re-review? | Chief Cloud Officer, Chief Architect, Chief Security Officer, Chief Open Source Officer. |
| Is G0 required again? | No. Public surface of existing crates is unchanged. |

## Consequences

### Positive

- Clear OSS vs Pro boundary for contributors and pub.dev extraction later.
- Play can keep a local-first privacy story.
- Overlay can implement `PurchaseProvider` and a networked `LicenseClient`
  without rewriting Aika call sites that already use `isEnabled`.

### Negative

- Play does not get central install counts until a later, reviewed analytics
  design.
- Phone `createProviderOverrides()` wiring remains a separate public follow-up.

### Risks

- Duplicate capability id lists (`AikaLicenseCapabilities` vs `ProFeature`)
  can drift. Tests freeze the id set.

## Alternatives Considered

### Alternative 1: Register every Play install with the hosted API

Rejected: conflicts with local-first and current Data Safety copy.

### Alternative 2: Put RevenueCat in public `app/pubspec.yaml`

Rejected: forces IAP onto the open store listing and leaks a private
commerce SDK into OSS.

### Alternative 3: Reuse `core_auth` principals as license identity

Rejected: that stack is login-shaped (Google/Apple/enterprise). License is
accountless.

## Related Decisions

- [OPEN_CORE.md](../OPEN_CORE.md)
- [open-source-boundary.md](../open-source-boundary.md)
- [airo-license implementation plan](../airo-license/implementation-plan.md)

## References

- Overlay sync: `DevelopersCoffee/airo-pro` PR #57
- Public deny-all: `DevelopersCoffee/airo` PR #2063
