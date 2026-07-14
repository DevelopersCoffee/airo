# Analytics Retention And Data Access Policy

Issue: ATV-079
Package: `core_analytics`
Layer: Platform framework, consumed by Airo TV app, privacy flows, and provider
adapters

## Purpose

Analytics retention and data-access policy defines how long each analytics
category may keep raw data, which deletion steps are required for consent or
privacy requests, and which roles can access each retention class. Airo TV app
code consumes the policy for settings and privacy workflows; it must not
hard-code retention windows, deletion steps, or data-access roles.

## Ownership

- Privacy owns retention windows, consent-withdrawal behavior, account/privacy
  deletion semantics, and export/delete scope.
- Data owns mappings from analytics retention classes to exportable categories.
- Security owns least-privilege roles, production-data approval gates, audit
  requirements, and public serialization boundaries.
- Framework owns `core_analytics` models, validation codes, deletion-plan
  builders, and deterministic access evaluation.
- Airo TV app code owns user-facing copy and workflow routing that consumes the
  platform policy.

## Retention Classes

`AiroAnalyticsRetentionClass` is enforced through
`AiroAnalyticsRetentionPolicy`:

- `operational_30_days`: raw operational events retain for 30 days and are not
  deleted by analytics consent withdrawal unless a privacy/account deletion
  request applies.
- `product_90_days`: raw product and playback-quality events retain for 90 days
  and are deleted when optional analytics consent is withdrawn.
- `diagnostics_30_days`: raw diagnostics retain for 30 days and are deleted
  when diagnostics consent is withdrawn.
- `crash_90_days`: redacted crash reports retain for 90 days and are deleted
  when crash-reporting consent is withdrawn.
- `aggregate_only`: exposes aggregate metadata only and has zero raw-retention
  days.

Policy validation returns stable codes for mismatched retention days, aggregate
raw retention, missing classes, and missing access roles or purposes.

## Deletion Plans

`AiroAnalyticsRetentionPolicy.deletionPlan(reason)` returns deterministic steps:

- Consent withdrawal clears local analytics queue, clears local crash
  diagnostics, resets analytics identity, requests provider delete, and writes
  an audit record for optional analytics purposes.
- Privacy and account deletion clear local data, reset identity, request
  provider export/delete, write aggregate tombstones, and write audit records.
- Retention expiry clears local retained records and requests provider delete
  for expired raw classes.

Provider-specific export/delete APIs are adapter work. The platform contract
defines the required steps and stable result surface.

## Least-Privilege Access

`AiroAnalyticsAccessRequest` evaluates:

- role;
- purpose;
- retention class;
- production-data flag;
- approval flag.

The standard Airo TV policy permits product analysts only for product
measurement over product or aggregate data. Privacy officers can evaluate
privacy requests. Security auditors can evaluate security investigations over
operational, diagnostics, crash, or aggregate data. Release engineers can use
operational, diagnostics, crash, or aggregate data for release quality.
Support-role access to production analytics is blocked.

Access decisions return stable codes for rejected roles, rejected purposes,
missing approvals, and production access blocks.

## Public Serialization

Public maps expose stable role ids, purpose ids, retention class ids, retention
days, deletion step ids, boolean approval state, and decision codes only. They
must not expose raw media titles, URLs, local paths, local IP addresses,
credentials, provider payloads, store-console accounts, viewing history, crash
stacks, or diagnostics dumps.

## Automation

- Unit tests validate the standard retention windows.
- Unit tests validate consent-withdrawal deletion plans for optional analytics.
- Unit tests validate privacy/account deletion plans with export/delete,
  aggregate tombstone, and audit steps.
- Unit tests reject support and product-role access outside least privilege.
- Unit tests reject invalid policies with deterministic validation codes.
- Public-map tests verify stable output without raw analytics or diagnostics
  material.

## Deferred Work

Provider-specific deletion/export APIs, backend data-warehouse enforcement,
data-access approval tooling, and Airo TV settings screens remain separate
issues. This issue defines the reusable platform contract those features must
consume.
