## Feature Packet

**Problem:** `app` on `origin/main` carries deterministic analyzer noise from unused imports, quote-style drift, and a constructor pattern lint in the LifeTrack status connector.
**User / actor:** Release and DevEx Agent maintaining repository health.
**Expected outcome:** `flutter analyze --no-fatal-infos --no-fatal-warnings` reports fewer issues without changing runtime behavior.
**Impacted modules:** `app/lib/core/app`, `app/lib/features/agent_chat`, `app/lib/features/live`, `app/lib/features/media`, `app/lib/features/media_hub`, `app/lib/features/music`, `app/lib/features/settings`, `app/test/features`.
**Constraints:** No behavior changes, no framework contract changes, no dependency upgrades in this slice.

### Critical Agent Gate

**Problem:** The app surface has 37 deterministic info-level analyzer findings that obscure higher-signal maintenance issues.
**User / actor:** Release and DevEx Agent.
**Framework or application layer:** Application.
**Owning agent:** Mobile UI Agent.
**Reviewing agents:** QA Automation Agent, Release and DevEx Agent.
**Impacted modules/files:** `app/lib/core/app/tv_router.dart`, `app/lib/features/agent_chat/data/connectors/life_track_status_connector.dart`, `app/lib/features/live/presentation/screens/live_screen.dart`, `app/lib/features/media/presentation/screens/media_hub_screen.dart`, `app/lib/features/media_hub/**`, `app/lib/features/music/application/providers/beats_queue_provider.dart`, `app/lib/features/settings/application/ai_model_management.dart`, `app/lib/features/settings/application/ai_preferences_settings.dart`, `app/lib/main*.dart`, `app/test/features/**`.
**Base branch/worktree:** confirmed from latest `origin/main`: yes (`cc9282b46417affa79f7fb7059b4e3a34313694b`).
**Open questions:** None. Scope is lint-only cleanup with no product behavior changes.
**Decision:** Ready

## Cross-Agent Contract

- The application layer may remove unused imports and normalize style where no user-visible behavior, data flow, or platform contract changes.
- QA validation for this slice is analyzer output reduction plus targeted tests covering touched media hub and settings surfaces.

## Deterministic Validation Flow

1. Run `cd app && flutter analyze --no-fatal-infos --no-fatal-warnings`.
2. Run `cd app && flutter test test/features/media_hub test/features/settings/application/ai_preferences_settings_test.dart --reporter=compact`.
3. Run `cd packages/core_data && flutter test --reporter=compact` as a representative framework regression guard because app code depends on shared platform adapters.
