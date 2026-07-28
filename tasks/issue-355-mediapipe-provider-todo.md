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
- [ ] Implement Android background sessions.
- [ ] Focused tests, analyzer, and Android compilation pass.

Evidence: 7 focused Dart tests pass; focused `flutter analyze` reports no
issues; all 64 package manifests pass.

## Task 5: Release composition

- [ ] Full profile includes the provider.
- [ ] TV and Coins exclude the provider and native runtime.
- [ ] Build-profile, manifest, variant, worker, and diff gates pass.
- [ ] Full APK delta is recorded.

## Task 6: Physical qualification

- [ ] Pixel 9 reconnects and pending reboot evidence is completed.
- [ ] Current full APK installs without clearing unrelated data.
- [ ] Airplane-mode embedding returns 384 unit-normalized values.
- [ ] Physical inference stays below 150 ms.
- [ ] Network/log evidence contains no telemetry or private payload.
- [ ] Test model/session cleanup is recorded.

## Task 7: Close-out

- [ ] #355 records exact implementation and physical evidence.
- [ ] Model distribution/attribution lifecycle is approved or remains explicit.
- [ ] #355 closes only when every issue acceptance criterion is satisfied.
