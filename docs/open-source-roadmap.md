# Airo Open-Source Program Roadmap

> **Vision**: Transform Airo's underlying technology into a suite of world-class, independent open-source Flutter packages and Rust crates under `DevelopersCoffee`.

---

## 8-Phase Release Execution Lifecycle

```text
 ┌─────────┐   ┌──────────────┐   ┌──────────────────┐   ┌─────────────┐
 │ Phase 0 │──>│   Phase 1    │──>│     Phase 2      │──>│   Phase 3   │
 │ Audit   │   │ Architecture │   │ Candidate Select │   │ Standalone  │
 └─────────┘   └──────────────┘   └──────────────────┘   └──────┬──────┘
                                                                │
 ┌─────────┐   ┌──────────────┐   ┌──────────────────┐          │
 │ Phase 7 │<──│   Phase 6    │<──│     Phase 5      │<─────────┘
 │ Community│  │ Airo Migrate │   │ Pub Release      │   ┌─────────────┐
 └─────────┘   └──────────────┘   └──────────────────┘   │   Phase 4   │
                                                         │ Hardening   │
                                                         └─────────────┘
```

---

## Phase Breakdown

### Phase 0 — Audit & Inventory
* Perform complete inventory of monorepo packages (`packages/`).
* Classify candidates by usefulness, coupling, maintenance cost, and security safety.
* **Deliverable**: `docs/open-source-candidate-audit.md`.

### Phase 1 — Architectural Boundaries
* Define public vs. private intellectual property rules.
* Establish non-negotiable dependency inversion rules: `Airo -> Public Package` (never `Public Package -> Airo`).
* **Deliverable**: `docs/open-source-boundary.md`.

### Phase 2 — First Candidate Selection
* Select the pilot candidate based on high community demand and low local coupling.
* Selected Pilot #1: **`dpad_qualification`** (Device resolution & D-Pad TV qualification harness).
* **Deliverable**: `docs/first-library-decision.md`.

### Phase 3 — Standalone Repository Creation
* Create public repository under `DevelopersCoffee` organization using `gh cli`.
* Set up standalone repository structure with `lib/`, `test/`, `example/`, `README.md`, `LICENSE`, `CHANGELOG.md`.
* **Deliverable**: [DevelopersCoffee/dpad_qualification](https://github.com/DevelopersCoffee/dpad_qualification).

### Phase 4 — Quality Hardening & CI Setup
* Configure GitHub Actions CI workflow for formatting, linting (`flutter analyze`), unit tests (`flutter test`), and package validation (`dart pub publish --dry-run`).
* Achieve 0 analyzer warnings and 100% test pass rate.
* Add comprehensive `example/` project.

### Phase 5 — Package Registry Release
* Publish package to `pub.dev` or `crates.io` using automated GitHub OIDC workflow.
* Tag releases with semantic versioning (`v1.0.0`).

### Phase 6 — Airo Monorepo Migration
* Update Airo monorepo `pubspec.yaml` to consume the external published package (`dpad_qualification: ^1.0.0`).
* Remove local duplicate package (`packages/platform_device_qualification`).
* Verify Airo compiles and passes all tests.
* **Deliverable**: `docs/open-source/dpad_qualification-migration.md`.

### Phase 7 — Developer Distribution & Content Engine
* Execute the technical content strategy (GitHub releases, technical articles, YouTube deep dives, community discussions).
* Engage open-source contributors and ingest community PRs.

### Phase 8 — Completed Extractions Matrix (10 Packages)

| Candidate Package | Tech Stack | GitHub Repository | Migration Record | Status |
|---|---|---|---|---|
| **`dpad_qualification`** | Flutter / TV | [DevelopersCoffee/dpad_qualification](https://github.com/DevelopersCoffee/dpad_qualification) | [`dpad_qualification-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/dpad_qualification-migration.md) | ✅ Released & Migrated |
| **`run_off_main`** | Dart / Isolate | [DevelopersCoffee/run_off_main](https://github.com/DevelopersCoffee/run_off_main) | [`run_off_main-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/run_off_main-migration.md) | ✅ Released & Migrated |
| **`iptv_org_api`** | Dart / API | [DevelopersCoffee/iptv_org_api](https://github.com/DevelopersCoffee/iptv_org_api) | [`iptv_org_api-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/iptv_org_api-migration.md) | ✅ Released & Migrated |
| **`airo_core`** | Rust / C-FFI | [DevelopersCoffee/airo_core](https://github.com/DevelopersCoffee/airo_core) | [`airo_core-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_core-migration.md) | ✅ Released & Migrated |
| **`airo_calendar`** | Flutter / OS | [DevelopersCoffee/airo_calendar](https://github.com/DevelopersCoffee/airo_calendar) | [`airo_calendar-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_calendar-migration.md) | ✅ Released & Migrated |
| **`airo_background_downloads`** | Flutter / Engine | [DevelopersCoffee/airo_background_downloads](https://github.com/DevelopersCoffee/airo_background_downloads) | [`airo_background_downloads-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_background_downloads-migration.md) | ✅ Released & Migrated |
| **`airo_job_scheduler`** | Flutter / Concurrency | [DevelopersCoffee/airo_job_scheduler](https://github.com/DevelopersCoffee/airo_job_scheduler) | [`airo_job_scheduler-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_job_scheduler-migration.md) | ✅ Released & Migrated |
| **`airo_analytics`** | Flutter / Privacy | [DevelopersCoffee/airo_analytics](https://github.com/DevelopersCoffee/airo_analytics) | [`airo_analytics-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_analytics-migration.md) | ✅ Released & Migrated |
| **`airo_pairing`** | Flutter / Security | [DevelopersCoffee/airo_pairing](https://github.com/DevelopersCoffee/airo_pairing) | [`airo_pairing-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_pairing-migration.md) | ✅ Released & Migrated |
| **`airo_protocol`** | Flutter / Protobuf | [DevelopersCoffee/airo_protocol](https://github.com/DevelopersCoffee/airo_protocol) | [`airo_protocol-migration.md`](file:///Users/udaychauhan/workspace/airo/docs/open-source/airo_protocol-migration.md) | ✅ Released & Migrated |

---

## Next Steps

1. **Package Registry Publishing (`pub.dev` & `crates.io`)**:
   - Publish `dpad_qualification`, `run_off_main`, `iptv_org_api`, `airo_calendar`, `airo_background_downloads`, `airo_job_scheduler`, `airo_analytics`, `airo_pairing`, and `airo_protocol` to `pub.dev`.
   - Publish `airo_core` crate to `crates.io`.
2. **Execute Developer Content & Distribution Strategy**:
   - Produce YouTube tutorials, dev.to/Medium articles, and Twitter/X technical threads for the open-source suite.


