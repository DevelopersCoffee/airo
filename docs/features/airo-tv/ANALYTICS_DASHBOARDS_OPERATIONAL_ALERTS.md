# Analytics Dashboards And Operational Alerts

Issue: ATV-080
Package: `core_analytics`
Layer: Platform framework, consumed by Airo TV reporting, SRE, and future
provider adapters

## Purpose

Analytics dashboard and alert contracts define the stable metric surfaces,
required metrics, alert rules, thresholds, severity, evaluation windows, and
runbook ids Airo TV uses for release and operational visibility. Product code
submits typed events and consumes evaluated reporting specs; it must not
hard-code vendor dashboard definitions or alert thresholds in app screens.

## Ownership

- Product owns executive, subscription, and product-success dashboard surfaces.
- Analytics owns metric ids, owners, aggregation intent, retention class, and
  dashboard requirements.
- SRE owns alert severity, thresholds, evaluation windows, and runbook ids.
- Security and Privacy owns public-map boundaries and prevents raw analytics,
  diagnostics, credentials, media, or network data from entering dashboard specs.
- Framework owns `core_analytics` models, validation codes, standard fixtures,
  and deterministic tests.

## Dashboard Surfaces

`AiroAnalyticsDashboardSurface` includes:

- `executive`
- `playback_quality`
- `legacy_device`
- `device_ecosystem`
- `subscription`
- `regression`

`AiroAnalyticsDashboardMetricSpec` defines stable metric id, owner, analytics
purpose, retention class, surface, dashboard requirement, aggregate-only flag,
and whether the metric may drive alerts.

The standard Airo TV catalog includes required metrics for weekly active
receivers, playback startup latency, legacy decoder fallback rate, pairing
success rate, subscription conversion rate, crash rate by profile, provider
outage rate, and privacy deletion latency.

## Alert Rules

`AiroAnalyticsOperationalAlertRule` defines:

- alert id;
- metric id;
- severity;
- greater-than or less-than comparison;
- finite threshold;
- positive evaluation window;
- runbook id.

The standard catalog includes deterministic rules for playback startup
regression, crash spikes by profile, legacy decoder fallback spikes, pairing
success regression, provider outage regression, and privacy deletion latency
breach.

## Validation

`AiroAnalyticsDashboardCatalog.validate()` returns stable codes for:

- duplicate metric ids;
- invalid metric ids;
- missing metric owners;
- missing required dashboard surfaces;
- alert references to unknown metrics;
- invalid alert thresholds;
- invalid alert windows;
- missing runbooks.

## Public Serialization

Public maps expose stable metric ids, owner ids, purpose ids, retention classes,
surface ids, threshold values, evaluation windows, severities, and runbook ids
only. They must not expose raw media titles, URLs, local paths, local IP
addresses, credentials, provider payloads, store-console accounts, viewing
history, crash stacks, or diagnostics dumps.

## Automation

- Unit tests validate that the standard catalog covers all required surfaces.
- Unit tests validate that every alert references a known metric and has a
  finite threshold, positive window, and runbook id.
- Unit tests reject invalid catalogs with deterministic validation codes.
- Public-map tests verify stable metadata without raw analytics or diagnostics
  material.

## Deferred Work

Vendor dashboard provisioning, alert delivery integrations, production SLO
tuning, Airo TV reporting UI, and executive report rendering remain separate
issues. This issue defines the reusable platform contract those features must
consume.
