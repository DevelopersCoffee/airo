# Implementation Plan: Super-App and Modular Shell Composition

## Overview

Make `core_product_shell` the composition source of truth for the Airo
super-app and focused TV/Coins apps. This issue delivers compile-time product
composition; it does not download or execute Dart/native plugin code.

Canonical tracker: https://github.com/DevelopersCoffee/airo/issues/1187

## Architecture Decisions

- Keep `ShellId` open-ended so future product shells do not require an enum
  migration.
- Keep domain UI and platform setup in application/module adapters; the
  framework package owns only composition contracts and validation.
- Fail before application bootstrap for duplicate module IDs and route
  conflicts. Silent composition ambiguity is not a recoverable runtime state.
- Migrate additively: Coins is the reference consumer, TV moves next, and the
  super-app follows after its hard-wired router has parity coverage.
- Treat runtime plugin downloads as signed data/assets only until #164 and
  #168 select and security-review a supported executable delivery mechanism.

## Dependency Graph

```text
core_product_shell validation
    |
    +-- TV module adapter and registry factory
    |       |
    |       +-- TV bootstrap/provider/startup migration
    |
    +-- super-app module adapters and registry factory
            |
            +-- super-app router/provider/startup migration
                    |
                    +-- product profile/dependency policy gate
```

## Task List

### Phase 1: Contract hardening

- [x] Reject duplicate module IDs.
- [x] Reject duplicate top-level route paths and route names.
- [x] Add deterministic contract tests for valid, unsupported, and conflicting
      registrations.

### Checkpoint: Framework contract

- [x] `core_product_shell` format, analyze, and tests pass.
- [x] Existing Coins composition tests remain green.

### Phase 2: TV vertical slice

- [x] Replace `FeatureRegistry` use in `main_tv.dart` with a TV-scoped
      `ModuleRegistry`.
- [x] Adapt IPTV to the shared `AppModule` contract without changing routes,
      storage keys, provider behavior, or TV UI.
- [x] Inject the registry into TV provider assembly and deferred module
      initialization.
- [x] Add exact production-registry tests proving TV includes IPTV and excludes
      Coins.

### Checkpoint: TV shell

- [x] Focused TV bootstrap tests pass.
- [x] TV target analyzes with the lean manifest workflow.

### Phase 3: Super-app vertical slice

- [x] Define the mobile registry factory and module adapters.
- [x] Route module provider overrides and lifecycle through the registry.
- [x] Move shell-nested module destinations into registry route bundles while
      retaining route compatibility.
- [x] Add super-app composition parity tests for stable route prefixes.
- [x] Add initial-journey parity coverage for the registry-owned route tree.

### Checkpoint: Super-app shell

- [x] Focused super-app composition/startup tests pass.
- [x] No shared module contract remains app-owned except a documented temporary
      façade.

### Phase 4: Product profile enforcement

- [x] Validate `module.yaml` ship policies against focused product manifests.
- [x] Prove TV excludes Never Ship Coins dependencies and Coins excludes IPTV.
- [x] Update ADR-0011 status, migration notes, rollback, and remaining work.

### Checkpoint: Complete

- [x] Super-app, TV, and Coins consume the same composition contract.
- [ ] Targeted format/analyze/test/build checks and `git diff --check` pass.
- [ ] Issue #1187 contains validation evidence.

## Risks and Mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Static registry state leaks across tests | High | Use one registry instance per shell/bootstrap. |
| Route migration breaks deep links | High | Preserve paths/names and assert exact parity. |
| Focused manifest still includes forbidden native packages | High | Add manifest/dependency policy validation before claiming size reduction. |
| Nested route identity conflicts make composition ambiguous | Medium | Recursively validate resolved module route paths and names before startup. |
| Compatibility façade becomes permanent | Medium | Track removal in this issue and ADR migration checklist. |

## Open Questions

- Which supported Android delivery mechanism, if any, will later carry
  executable feature code? This remains blocked in #164/#168 and does not
  block compile-time modular apps.
- Whether first-class `apps/airo_tv` and `apps/airo_coins` directories replace
  alternate entrypoints in this milestone or a follow-up after profile gates.
