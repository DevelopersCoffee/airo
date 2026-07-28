# #355 Telemetry-Free MediaPipe Provider Tasks

## Task 1: Governance

- [x] Inspect official model dimensions before selection.
- [x] Produce a real 384-dimensional MediaPipe feasibility artifact.
- [x] Audit current and official-sample Android SDK AARs.
- [x] Record hidden telemetry and the required remediation.
- [x] Post the cross-agent Feature Packet with a Ready decision.

Evidence:
<https://github.com/DevelopersCoffee/airo/issues/355#issuecomment-5101455964>

## Task 2: Core contract

- [x] Write failing provider/model/failure contract tests.
- [x] Implement immutable typed contracts.
- [x] Focused tests and analyzer pass.

Evidence: 6 focused tests pass; focused `flutter analyze` reports no issues.

## Task 3: Dependency remediation

- [x] Add pinned input hash and deterministic patch script.
- [x] Derive the no-telemetry core AAR.
- [x] Preserve license/NOTICE and record modification.
- [x] Prove remote logger, proto, and DataTransport are absent.

Evidence: two derivations were byte-identical at
`36366b6b3ee7cb8279e3b3dd608774f4f30298296e56d6ff23f7f083d4bc0416`;
the artifact audit passes.

## Task 4: Platform adapter

- [x] Create the owned package and manifest.
- [x] Write failing channel/lifecycle/redaction tests.
- [x] Implement Dart adapter and unsupported-platform behavior.
- [x] Implement Android background sessions.
- [x] Focused tests, analyzer, and Android compilation pass.

Evidence: 7 focused Dart tests pass; focused `flutter analyze` reports no
issues; 3 focused Kotlin contract tests pass; the integrated Android plugin
compiles and bundles; all 64 package manifests pass.

## Task 5: Release composition

- [x] Full profile includes the provider.
- [x] TV and Coins exclude the provider and native runtime.
- [x] Build-profile, manifest, variant, worker, and diff gates pass.
- [x] Full APK delta is recorded.

Evidence: the full arm64 debug APK increases by 7,485,020 bytes (7.138 MiB)
against the same-commit profile baseline. The provider runtime graph contains
the audited local core and `tasks-text`, with no published `tasks-core` or
DataTransport. No model is bundled.

## Task 6: Physical qualification

- [x] API 36 ARM64 emulator proves real offline 384-dimensional inference,
      unit norm, repeat determinism, typed close, and test-model cleanup.
- [ ] Pixel 9 reconnects and pending reboot evidence is completed.
- [ ] Current full APK installs without clearing unrelated data.
- [ ] Airplane-mode embedding returns 384 unit-normalized values.
- [ ] Physical inference stays below 150 ms.
- [ ] Network/log evidence contains no telemetry or private payload.
- [ ] Test model/session cleanup is recorded.

Exploratory evidence:
`artifacts/performance/2026-07-28-mediapipe-embedding-emulator.md`. This does not
replace any physical-device checkbox above.

## Task 6a: Meeting consumer integration

- [x] #506 exposes an asynchronous embedding-stage provider contract.
- [x] The app adapter consumes `LocalTextEmbeddingProvider` without duplicating
      platform inference.
- [x] Redacted transcript input, exact model identity, typed failures, and
      vector-free diagnostics are covered by host tests.
- [x] Successful vectors persist through existing meeting embedding columns;
      no schema migration or model bundle was added.
- [ ] The approved model lifecycle opens and injects the production provider.

## Task 7: Close-out

- [ ] #355 records exact implementation and physical evidence.
- [ ] Model distribution/attribution lifecycle is approved or remains explicit.
- [ ] #355 closes only when every issue acceptance criterion is satisfied.
