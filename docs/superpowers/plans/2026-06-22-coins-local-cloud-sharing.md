# Coins Local And Cloud Sharing

## Decision

Keep personal money management local-first by default.

Cloud mode is opt-in and scoped to shared groups. A user must explicitly enable
cloud sharing with Google sign-in before creating or sharing a group invite.
Local personal transactions must not upload just because the user opens Coins.

## Current Slice

Implemented the app-side gate:

- Local / Cloud segmented control on the Groups screen.
- Google sign-in required before cloud sharing.
- Shared group creator identity uses the Google user in cloud mode.
- Group invite sharing creates a versioned HTTPS invite link.
- Join flow accepts raw invite codes and pasted invite links.

## Recommended Backend Path

Use Firebase Auth for identity and Firestore for the first cloud sync backend.

Reasons:

- Airo already initializes Firebase and supports Google sign-in.
- Firestore supports offline reads/writes/listeners on supported clients.
- Firebase Dynamic Links is deprecated, so invite links should use Airo-owned
  HTTPS links plus app/deep-link handling, not Firebase Dynamic Links.

## Data Boundary

Do not sync the local personal ledger by default.

Sync eligible data:

- shared groups
- group members
- shared expenses
- split entries
- settlements
- invite metadata
- event/outbox records for those shared entities

Local-only by default:

- personal transactions
- personal budgets
- account balances
- private receipt attachments
- local AI finance insights

## Cloud Data Contract

Firestore shape should be append-friendly:

```text
users/{uid}
groups/{groupId}
groups/{groupId}/members/{uid}
groups/{groupId}/events/{eventId}
groups/{groupId}/invites/{inviteTokenHash}
```

Event types:

- group.created
- group.updated
- member.joined
- member.removed
- expense.added
- expense.updated
- expense.deleted
- settlement.recorded
- settlement.completed

Each event should include:

- eventId
- groupId
- actorUid
- deviceId
- clientCreatedAt
- serverCreatedAt
- entityId
- entityVersion
- payload

## Invite Flow

1. Owner enables cloud mode.
2. Owner creates or opens group.
3. App creates short-lived invite token in cloud backend.
4. App shares `https://airo.app/coins/join?...`.
5. Receiver opens link or pastes code.
6. Receiver signs in with Google.
7. Backend validates invite and creates membership.
8. Device downloads group event log and rebuilds local group state.

## Conflict Rules

- Events are immutable.
- Updates carry entity versions.
- Deletes are tombstones.
- Expense amount/category changes use last-write-wins only when versions match.
- Split/settlement conflicts should produce a review-required state.

## Acceptance Gates

- Local mode works without Google sign-in.
- Cloud mode cannot be enabled without Google sign-in.
- Sharing a group invite prompts cloud mode when needed.
- Invite links are versioned and parseable.
- Personal transactions do not sync by default.
- Backend rules allow group reads/writes only for group members.
- Sync can replay a group event log into local SQLite deterministically.
