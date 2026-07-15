# Crash Reporting Redaction Contract

## Ownership

ATV-076 is a platform analytics and security contract. `packages/core_analytics`
owns the crash report envelope, redaction policy, consent/local-only upload
blocking, no-op/local/provider-backed crash reporting adapters, and public
serialization.

Airo TV application code may submit crash summaries to the platform adapter. It
must not import a crash vendor SDK directly, upload raw crash payloads, or
implement separate redaction rules in app code.

## Crash Envelope

`AiroCrashReport` accepts stable metadata:

- report id
- capture time
- severity
- crash kind
- app version
- platform
- product profile
- device tier
- active module
- memory pressure bucket
- decoder family
- optional context field map
- stack frames
- native symbols

Public maps expose metadata, context field names, and stack/native counts only.
They do not expose raw context values, stack frame text, or native symbol text.

## Redaction

`AiroCrashRedactionPolicy.standard` redacts or rejects unsafe crash context:

- media URLs and signed URLs
- HTTP headers and cookies
- local paths
- local IP addresses
- provider domains
- media titles, program titles, and channel names
- search/query text
- prompt and transcript text
- credential-like values
- provider payloads

Stack frames and native symbols are replaced before local retention or provider
upload. Redaction results expose stable redaction codes and redacted field names.

## Adapters

- `AiroNoOpCrashReportingService`: validates and redacts without retaining or
  uploading.
- `AiroLocalDiagnosticsCrashReportingService`: stores bounded redacted crash
  diagnostics when diagnostics/local-only policy permits it.
- `AiroProviderBackedCrashReportingService`: sends only redacted reports through
  an isolated provider sender and converts provider failures into stable results.

## Consent Behavior

- Collection disabled returns `dropped_by_collection_disabled`.
- Crash consent disabled returns `dropped_by_consent` unless local diagnostics
  consent allows local storage.
- Local-only mode returns `stored_local_only` for local diagnostics and
  `upload_blocked_local_only` for provider-backed upload.
- Provider failures return `provider_unavailable` without throwing through
  playback or UI code.

## Deferred Work

Native crash collection hooks, provider-specific symbol upload, production
alerts/dashboards, and user-facing crash reporting settings are out of scope for
ATV-076 and should be tracked separately.
