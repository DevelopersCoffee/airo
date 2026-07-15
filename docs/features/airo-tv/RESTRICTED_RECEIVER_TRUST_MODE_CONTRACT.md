# Restricted Receiver Trust Mode Contract

Issue: ATV-056
Package: `core_pairing`
Layer: Platform framework, consumed by Airo TV application code

## Purpose

Restricted receiver trust mode protects older or less secure TV receivers by
limiting them to playback-ticket redemption, basic scoped control, playback
state reporting, and limited diagnostics. It prevents the receiver from
receiving full source credentials, raw source handles, billing authority,
profile management authority, admin authority, or trusted-device management
authority.

This contract belongs in platform code because receiver trust decisions are
shared by pairing, receiver modes, media routing, remote control, secure
playback tickets, and QA automation. Airo TV should consume the decision result
instead of encoding restricted trust rules in screens or feature workflows.

## Platform Contract

`AiroRestrictedReceiverTrustPolicy.evaluate` accepts:

- a trusted-device relationship;
- the requested restricted receiver action;
- the target receiver id;
- the current time;
- optional session id and playback ticket for ticket redemption.

The decision includes:

- relationship id;
- receiver id;
- action id;
- stable trust codes;
- mapped trusted-device access code;
- mapped playback-ticket validation code when ticket redemption is evaluated.

Public maps expose stable ids and codes only. They must not expose raw source
handles, local paths, provider payloads, private access material, media titles,
viewing history, account values, or billing values.

## Allowed Restricted Actions

Restricted receivers may:

- redeem a valid receiver-bound, session-bound playback ticket;
- accept basic playback control when the trusted-device relationship has
  playback control scope;
- report playback state when the relationship has diagnostics scope;
- expose limited diagnostics when the relationship has diagnostics scope.

These actions are still denied if the trusted-device relationship is missing
scope, not yet valid, expired, revoked, or bound to another receiver.

## Denied Restricted Actions

Restricted receivers must deny:

- playback-ticket issuing;
- source credential reads;
- raw source handle reads;
- admin actions;
- billing actions;
- profile management;
- trusted-device management.

These actions are denied even if the controller has a broader trust level,
because restricted mode describes the receiver capability and risk posture.

## Deterministic Use Cases

1. A restricted receiver with a scoped, unexpired, non-revoked relationship and
   a valid playback ticket accepts ticket redemption.
2. Playback state reporting and limited diagnostics require diagnostics scope.
3. Basic playback control requires playback control scope.
4. Expired, revoked, not-yet-valid, wrong-scope, or wrong-receiver
   relationships deny the action with stable codes.
5. Missing, expired, revoked, reused, wrong-receiver, wrong-session, or
   wrong-scope playback tickets deny ticket redemption with stable mapped codes.
6. Credential, raw source, admin, billing, profile, and trusted-device
   management actions are denied in restricted mode.
7. Public diagnostics expose ids and stable codes only.

## Automation

- Unit tests use fixed clocks and deterministic trusted-device records.
- Policy tests cover accepted ticket redemption, scoped reporting/control,
  privileged action denial, relationship failure, ticket failure, and public
  diagnostic redaction.
- Package checks run with `flutter test` and `flutter analyze --fatal-infos`
  from `packages/core_pairing`.
