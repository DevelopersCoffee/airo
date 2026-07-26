# Planned: Personal Channel, Media Concierge, and Scheduler

Status: Planned design for Airo TV Pro; no v0.0.5 implementation or delivery
date.

## Customer outcomes

- Personal TV Channel assembles a transparent queue from the user’s own
  authorized catalog.
- Media Concierge answers bounded requests such as “I have thirty minutes”
  with explainable options, not an autonomous playback decision.
- AI Scheduler proposes reminders or routines and requires confirmation before
  creating external calendar or notification state.

## Data requirements

Inputs are local watch progress, explicit likes/hides, programme duration,
availability windows, content metadata with provenance, device time zone, and
optional calendar free/busy windows. Sensitive calendar text is minimized to
availability ranges unless the user explicitly grants broader access.

The design depends on versioned Media Graph and watch-pattern contracts
(#882/#905). Until those land, no local heuristic may masquerade as the
accepted schema. Deletes and privacy reset remove derived profiles and queues.

## Device/cloud split

On-device workers build bounded candidates, enforce availability and parental
rules, and rank deterministic fallbacks. Optional cloud reasoning may reorder
opaque candidate facts only after consent; it never receives playlist
credentials or directly controls playback. CE search, guide, reminders, and
manual queues remain usable without Pro.

## Entitlement gates

Proposed reviewed IDs are `personal_tv_channel`, `media_concierge`, and
`ai_scheduler`. Gate navigation entry points, worker scheduling, cloud calls,
and persistence through `Entitlements.isEnabled` plus private `ProModule`
lifecycle. ADR 0014's lifecycle controller, cancellable job, and entitlement
generation fence are prerequisites; current one-shot APIs are not sufficient.
A denied/revoked gate shows a stable unavailable or upgrade surface, cancels
or fences late work, and deletes all Pro-derived transient/persisted data. It
must not remove authorized inputs or CE manual equivalents.

## Evaluation

Use synthetic profiles to measure constraint satisfaction, explanation
correctness, schedule collision rate, opt-out deletion, and deterministic
fallback behavior. Human confirmation is mandatory for calendar writes,
reminders, purchases, and playback that changes the current session. Scheduler
also requires a versioned write contract for consent, idempotency,
conflict/retry, revocation, and rollback before implementation.
