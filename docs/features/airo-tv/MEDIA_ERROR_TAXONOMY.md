# Shared Airo Media Error Taxonomy

Status: v2 platform contract for ATV-030.

## Ownership

Shared media error classification is platform behavior. Airo TV can map stable
message keys to localized copy later, but category, severity, retryability,
safe context references, diagnostic handles, and redaction rules belong in
`packages/platform_media`.

Backend-specific packages can keep local error codes, but they should map those
codes into the shared taxonomy before analytics, diagnostics, retries, support
bundles, or app UI consume them.

## Non-Goals

This issue does not implement:

- localized user-facing strings
- analytics event upload
- crash reporting adapters
- support bundle export
- backend/native exception mapping
- app error screens

## Contract Shape

`AiroMediaErrorDescriptor` describes:

- error code
- category
- severity
- retryability
- stable user message key
- safe context refs
- diagnostic codes
- optional redacted diagnostic handle

`AiroDefaultMediaErrorClassifier` maps shared codes for source, auth, network,
decoder, capability, route, playback, import, EPG, storage, protocol, analytics,
and unknown failures.

`AiroMediaErrorClassifier` is the adapter boundary for future platform modules.
The package includes:

- `AiroNoOpMediaErrorClassifier`
- `AiroFakeMediaErrorClassifier`

## Privacy

Error descriptors must expose stable ids, message keys, category, severity,
retryability, context kinds, diagnostic codes, and redacted handles only. They
must not expose raw media URLs, playlist URLs, EPG URLs, request headers,
provider domains, local paths, local addresses, credentials, titles, search
text, viewing history, analytics payloads, or diagnostic dumps.
