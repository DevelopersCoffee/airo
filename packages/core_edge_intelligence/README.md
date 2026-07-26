# core_edge_intelligence

`core_edge_intelligence` owns the versioned, player-agnostic contract between
an intent-producing runtime and a media-engine adapter.

The public v1 shape is `IntentCommand`:

```json
{
  "intent": "search",
  "entities": [{"type": "genre", "value": "news"}],
  "filters": [{"field": "language", "operator": "equals", "value": "hi"}],
  "sort": null,
  "confidence": 0.94
}
```

Use `IntentCommand.validateJson` on untrusted model output. Invalid output
returns path-specific issues and must not reach `IntentExecutor`.

## Schema source

The vendored schema is at
`schemas/intent-command/v1/schema.json`. Its intended upstream authority is
`DevelopersCoffee/barista-tuning#2`. On 2026-07-27, that repository's checked-in
`schemas/intent/v1/schema.json` still had a different generic intent-result
shape. The mismatch is tracked explicitly; Airo does not claim the two
artifacts are identical until the upstream schema is reconciled.

Within v1, schema changes are additive only. Breaking changes require a new
major schema path and Dart API.
