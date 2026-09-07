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

### Phase 8 — Continuous Iteration
* Repeat lifecycle for Pilot #2 (`run_off_main`), Pilot #3 (`iptv_org_api`), and Pilot #4 (`airo_core` Rust crate).
