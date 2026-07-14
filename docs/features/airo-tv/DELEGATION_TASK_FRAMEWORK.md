# Airo TV Delegation Task Framework

ATV-063 defines the reusable platform framework for delegating work from
constrained Airo TV profiles to trusted helper nodes.

The contract lives in `packages/core_delegation` because delegation lifecycle,
deduplication, timeout, encrypted-payload checks, cancellation, result
versioning, and fallback behavior are shared by search, EPG, metadata, artwork,
source-resolution, stream-health, subtitle, playback, and transcoding flows.
Airo TV app code should consume the framework decision and keep only
user-facing workflow and copy.

## Ownership

- Framework owns task IDs, task kinds, result versions, task records,
  cancellation state, deduplication, and selection policy.
- Media owns task kinds and result semantics for search, EPG, metadata,
  subtitles, stream health, artwork, source resolution, playback assistance, and
  transcoding.
- Security owns encrypted-payload requirements and redacted public maps.
- QA owns failure fixtures for timeout, cancellation, duplicate suppression,
  candidate rejection, fallback, and unavailable states.
- Airo TV app code consumes dispatch decisions and fallback state; it must not
  reimplement delegation lifecycle checks inside screens.

## Task Request

`AiroDelegationTaskRequest` includes:

- `taskId`: stable unique task ID.
- `deduplicationKey`: stable key used to suppress duplicate execution.
- `kind`: delegated work type.
- `createdAt` and `timeout`: deadline contract declared by the requester.
- `requiresEncryptedPayload`: whether sensitive delegated work requires an
  encrypted payload reference.
- `hasEncryptedPayload`: whether encrypted payload metadata is present.
- `requiredResultVersion`: result schema version expected by the requester.

Public task maps expose IDs, kind, deadline, timeout, encryption booleans, and
result version only. Payload content is never included.

## Task Kinds

The initial framework supports stable task kinds for:

- search
- playlist parsing
- EPG processing
- metadata matching
- AI intent parsing
- subtitle lookup
- stream-health ranking
- artwork resizing
- source resolution
- credential-assisted playback
- transcoding

## Selection Policy

`AiroDelegationPolicy.select()` evaluates:

1. request validation
2. expiration
3. cancellation
4. encrypted-payload requirement
5. duplicate suppression by deduplication key
6. candidate capability confirmation
7. candidate trust
8. candidate availability
9. candidate latency against the request timeout
10. fallback when no candidate qualifies

Accepted decisions contain a selected candidate and no blockers. Rejected
decisions contain stable blocker codes, an existing task record for duplicate
suppression when available, or a fallback decision when user-visible unavailable
state is needed.

## Result Envelope

`AiroDelegationResultEnvelope` includes:

- `taskId`
- terminal `status`
- `resultVersion`
- `completedAt`
- redacted result-reference presence
- fallback kind when used

String output and public maps do not include raw result references.

## Airo TV Consumption Rule

Airo TV should run delegation policy before it stops local playback, hides local
UI, shows remote search/guide data, or claims helper-node support. If policy
returns fallback, Airo TV should show the user-visible unavailable state or use a
compact local fallback rather than attempting direct app-layer delegation.

## Public Serialization

Public maps expose stable IDs, task kind, timeout, result version, status,
fallback reason, and redacted reference presence. They do not include local
filesystem paths, provider payloads, store-console account data, raw credential
material, or device logs.
