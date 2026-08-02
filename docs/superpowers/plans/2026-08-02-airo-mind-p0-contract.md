# Airo Mind P0 Contract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze the `MindRuntime` port, ship a deterministic fixture behind it, build the five rule-carrying widgets, and make rules R01–R05 fail loudly when broken — so that milestone 22's fourteen surfaces can be built before milestone 19's runtime exists.

**Architecture:** `packages/feature_mind` gains a `runtime/` layer: immutable domain models, eight abstract sub-ports aggregated by a `MindRuntime` interface, and two implementations — `FixtureMindRuntime` (deterministic, seeded with the design's own numbers) and `RustMindRuntime` (delegates to FRB, throws `MindUnavailable` per unimplemented sub-port). Screens never import the generated bridge. Rules R01–R04 are widget and golden tests carried by five shared widgets; R03 and R05 additionally get repo-wide shell checks in `scripts/`, matching the existing `check-*.sh` policy-gate pattern.

**Tech Stack:** Dart 3.12 / Flutter, `flutter_test`, melos workspace, `flutter_rust_bridge` 2.11.1 (already pinned), bash + ripgrep for policy gates.

**Issue:** [#1449](https://github.com/DevelopersCoffee/airo/issues/1449) · **Spec:** `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md` · **Epic:** #1448

## Global Constraints

- Dart SDK `^3.12.2`, Flutter `>=3.0.0`. Match `packages/feature_mind/pubspec.yaml`.
- **No new third-party dependencies.** P0 adds `core_ui` (first-party) and nothing else. A new external package triggers a chief-open-source-officer scorecard and is out of scope.
- `packages/feature_mind/module.yaml` currently declares `allowed_dependencies: []`. Adding `core_ui` requires editing that file — Task 13. Do not add the dependency before that task, the module-manifest check will fail.
- **No screen or widget may import `package:feature_mind/src/api/...` or `frb_generated*`.** The existing rule in `feature_mind.dart` — "a consumer that reaches into `src/` has coupled itself to a code generator's output" — extends to the whole module. Only `rust_mind_runtime.dart` may import the bridge.
- **No parse over ~50 KB on the main isolate.** Per `CLAUDE.md`, use `runOffMain()` from `core_workers`. Nothing in P0 crosses that threshold; keep it that way.
- Every rule R01–R05 carries a **mutation test**: a test whose only failing cause is removing that rule's enforcement. A green check that cannot fail proves nothing. This is the existing governance standard on Mind — see `docs/AIRO_MIND_ARCHITECTURE_FREEZE_v1.md` and the proof-ledger convention.
- Comments explain **why**, not what. Match the existing voice in `mind_service.dart`. Do not add comments that restate the line below them.
- Analyzer runs with `--fatal-infos`. Formatting is `dart format` with exit-if-changed.
- Verification commands, run from the repo root unless stated:
  - Package tests: `cd packages/feature_mind && flutter test`
  - App tests: `cd app && flutter test`
  - Analyze one package: `cd packages/feature_mind && flutter analyze --fatal-infos`
  - Format: `dart format --set-exit-if-changed .`

---

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `packages/feature_mind/lib/src/runtime/models/vault_models.dart` | `VaultState`, `MindDevice`, `DeviceFingerprint`, `RevocationEntry` |
| `packages/feature_mind/lib/src/runtime/models/log_models.dart` | `MindOp`, `MindOpKind`, `SignatureState` |
| `packages/feature_mind/lib/src/runtime/models/context_models.dart` | `MindContext`, `ContextLink` |
| `packages/feature_mind/lib/src/runtime/models/projection_models.dart` | `ProjectionKind`, `ProjectionStatus`, `ProjectionState`, `SearchHitRef` |
| `packages/feature_mind/lib/src/runtime/models/mesh_models.dart` | `MindPeer`, `PeerLiveness`, `PairingRequest` |
| `packages/feature_mind/lib/src/runtime/models/capability_models.dart` | `InstalledCapability`, `CapabilitySafetyClass` |
| `packages/feature_mind/lib/src/runtime/models/model_models.dart` | `MindModel`, `ModelResidency`, `ModelBench`, `ThermalState` |
| `packages/feature_mind/lib/src/runtime/models/portability_models.dart` | `RecoveryPackagePlan`, `ContentClassSize`, `PackageDestination` |
| `packages/feature_mind/lib/src/runtime/ports/*.dart` | Eight abstract sub-ports, one file each |
| `packages/feature_mind/lib/src/runtime/mind_runtime.dart` | `MindRuntime` aggregate + `MindPortUnavailable` |
| `packages/feature_mind/lib/src/runtime/fixture/fixture_data.dart` | The design's numbers, as `const` data |
| `packages/feature_mind/lib/src/runtime/fixture/fixture_mind_runtime.dart` | `FixtureMindRuntime` |
| `packages/feature_mind/lib/src/runtime/rust/rust_mind_runtime.dart` | `RustMindRuntime`, partial |
| `packages/feature_mind/lib/src/widgets/mind_presence_pip.dart` | R01 |
| `packages/feature_mind/lib/src/widgets/mind_number_strip.dart` | R04 |
| `packages/feature_mind/lib/src/widgets/mind_context_chip.dart` | R02 |
| `packages/feature_mind/lib/src/widgets/mind_projection_switcher.dart` | R03 |
| `packages/feature_mind/lib/src/widgets/mind_op_row.dart` | Op provenance row |
| `packages/feature_mind/lib/testing.dart` | Rule harness, exported separately from the product library |
| `packages/feature_mind/lib/src/testing/mind_rule_harness.dart` | `expectSatisfiesMindRules` |
| `packages/feature_mind_absent/` | No-op swap package (R05) |
| `scripts/check-mind-projection-routes.sh` | R03 repo gate |
| `scripts/check-mind-private-devices.sh` | R05 repo gate |

**Modified**

| Path | Change |
|---|---|
| `app/lib/features/mind/**` → `app/lib/features/wellbeing/**` | Task 1 |
| `app/lib/core/providers/navigation_provider.dart` | `AppNavigationTab.mind` → `.wellbeing`, path `/mind` → `/wellbeing` |
| `app/lib/core/routing/app_router.dart` | Route paths and names |
| `app/lib/core/app/app_shell.dart` | `/mind/notifications`, `/mind/profile` |
| `app/lib/core/theme/airo_domain_resolver.dart` | Path prefix match |
| `app/test/features/mind/**` → `app/test/features/wellbeing/**` | Task 1 |
| `packages/feature_mind/lib/feature_mind.dart` | Export the runtime and widgets |
| `packages/feature_mind/module.yaml` | Allow `core_ui` |
| `packages/feature_mind/pubspec.yaml` | Add `core_ui` path dependency |
| `melos.yaml` | Register the two new scripts |

---

### Task 1: Free the Mind name — rename the wellbeing hub

`app/lib/features/mind/` is not Airo Mind. It is the wellbeing hub: a greeting card, a daily quote, and links to a chat and a models screen. It occupies the directory, the route `/mind`, the nav tab enum value `mind`, and the tab label "Mind". Every later task in milestone 22 would have to work around that, so it goes first.

There are no external deep links to `/mind` — checked `AndroidManifest.xml`, `Info.plist`, and `web/manifest.json`. So no compatibility redirect is added: `/mind` becomes unrouted here and is claimed by the Mind module in P4. A redirect would defeat the point.

**Files:**
- Move: `app/lib/features/mind/` → `app/lib/features/wellbeing/`
- Move: `app/test/features/mind/` → `app/test/features/wellbeing/`
- Modify: `app/lib/core/providers/navigation_provider.dart:31`
- Modify: `app/lib/core/routing/app_router.dart:84`, `:87`, `:224-231`
- Modify: `app/lib/core/app/app_shell.dart:83-84`
- Modify: `app/lib/core/theme/airo_domain_resolver.dart:14`

**Interfaces:**
- Consumes: nothing.
- Produces: the route prefix `/wellbeing` and `AppNavigationTab.wellbeing`. The path `/mind` and the name `Mind` are free from this task onward — P4 claims them.

- [ ] **Step 1: Write the failing test**

Create `app/test/core/routing/mind_name_is_free_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Airo Mind claims `/mind` in P4. Until then nothing else may hold it, and
/// the wellbeing hub held it for four months. This test is what stops it
/// coming back.
void main() {
  test('no route, tab, or directory called mind outside feature_mind', () {
    final offenders = <String>[];

    final lib = Directory('lib');
    for (final entity in lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final pattern in [r"'/mind'", r"'/mind/", r'features/mind/']) {
        if (source.contains(pattern)) {
          offenders.add('${entity.path}: $pattern');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The wellbeing hub must not hold the Mind name:\n'
          '${offenders.join('\n')}',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd app && flutter test test/core/routing/mind_name_is_free_test.dart`

Expected: FAIL, listing `lib/core/providers/navigation_provider.dart`, `lib/core/routing/app_router.dart`, `lib/core/app/app_shell.dart`, `lib/core/theme/airo_domain_resolver.dart`.

- [ ] **Step 3: Move the directories**

```bash
cd app
git mv lib/features/mind lib/features/wellbeing
git mv test/features/mind test/features/wellbeing
```

- [ ] **Step 4: Rename the tab**

In `app/lib/core/providers/navigation_provider.dart`, the enum member at line 31:

```dart
  wellbeing(
    label: 'Wellbeing',
    path: '/wellbeing',
    icon: Icons.psychology_outlined,
    selectedIcon: Icons.psychology,
  ),
```

Then update the two path lists further down the same file (around lines 218 and 230): `'/mind'` → `'/wellbeing'`, `'/mind/chat'` → `'/wellbeing/chat'`, `'/mind/models'` → `'/wellbeing/models'`, `'/mind/'` → `'/wellbeing/'`. Update every `AppNavigationTab.mind` reference the analyzer reports to `AppNavigationTab.wellbeing`.

- [ ] **Step 5: Rename the routes**

In `app/lib/core/routing/app_router.dart`:

```dart
            // Wellbeing branch
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/wellbeing',
                  name: 'Wellbeing',
                  builder: (context, state) => const WellbeingScreen(),
```

Update the nested `name:` values from `mind_chat` etc. to `wellbeing_chat` etc., and fix the two redirects at lines 84 and 87 to target `/wellbeing`. Leave `/agent` pointing at `/wellbeing` for now — P1 surface 02 repoints it at Mind's agent chat, and doing it here would break a route with nothing to replace it.

In `app/lib/core/app/app_shell.dart`, lines 83–84: `/wellbeing/notifications` and `/wellbeing/profile`.

In `app/lib/core/theme/airo_domain_resolver.dart`, line 14: `path.startsWith('/wellbeing')`.

- [ ] **Step 6: Rename the class and its file**

```bash
cd app
git mv lib/features/wellbeing/presentation/screens/mind_screen.dart \
       lib/features/wellbeing/presentation/screens/wellbeing_screen.dart
git mv test/features/wellbeing/presentation/screens/mind_screen_test.dart \
       test/features/wellbeing/presentation/screens/wellbeing_screen_test.dart
```

Rename `MindScreen` to `WellbeingScreen` and `_MindScreenState` to `_WellbeingScreenState` inside it, plus `_MindActionCard` to `_WellbeingActionCard`. Update the import in `app_router.dart` and the two test files. Update the doc comment to read:

```dart
/// Wellbeing hub for reflection and light motivation.
///
/// Not Airo Mind — that is `packages/feature_mind`. This screen held the
/// `/mind` route until milestone 22 needed it back.
```

- [ ] **Step 7: Run the full app suite**

Run: `cd app && flutter test`

Expected: PASS, including `mind_name_is_free_test.dart`. Fix any test that referenced the old names.

- [ ] **Step 8: Analyze and format**

Run: `cd app && flutter analyze --fatal-infos && dart format --set-exit-if-changed .`

Expected: no issues.

- [ ] **Step 9: Commit**

```bash
git add -A app
git commit -m "refactor(app): rename the wellbeing hub off the Mind name

app/lib/features/mind is the wellbeing hub, not Airo Mind. It held the
/mind route, the AppNavigationTab.mind value and the tab label, all of
which milestone 22 needs. No external deep link points at /mind, so the
path is freed rather than redirected — P4 claims it.

Closes #1203"
```

---

### Task 2: Domain models

Immutable value types the ports exchange. Eight files, each paired with the port that returns it, so a change to the mesh model touches one file and not a shared grab-bag.

These are hand-written, not generated. They are the frozen contract; a code generator's output is not a contract.

**Files:**
- Create: `packages/feature_mind/lib/src/runtime/models/vault_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/log_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/context_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/projection_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/mesh_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/capability_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/model_models.dart`
- Create: `packages/feature_mind/lib/src/runtime/models/portability_models.dart`
- Test: `packages/feature_mind/test/runtime/models_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: every type listed in the File Structure table. Tasks 3–12 use these exact names and field names.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/runtime/models_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('value semantics', () {
    test('two ops with the same fields are equal', () {
      const a = MindOp(
        sequence: 12481,
        kind: MindOpKind.automation,
        title: 'Ibuprofen 400 mg logged',
        contextId: 'kneesurgery2026',
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        recordedAtMs: 1754024 * 1000000,
      );
      const b = MindOp(
        sequence: 12481,
        kind: MindOpKind.automation,
        title: 'Ibuprofen 400 mg logged',
        contextId: 'kneesurgery2026',
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        recordedAtMs: 1754024 * 1000000,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('an op that failed verification is not equal to one that passed', () {
      const verified = MindOp(
        sequence: 1,
        kind: MindOpKind.note,
        title: 't',
        contextId: 'c',
        deviceName: 'd',
        signature: SignatureState.verified,
        recordedAtMs: 0,
      );
      final unverified = verified.copyWith(
        signature: SignatureState.unverified,
      );

      expect(verified, isNot(equals(unverified)));
    });
  });

  test('a context reports its own item count', () {
    const context = MindContext(
      id: 'kneesurgery2026',
      label: '#KneeSurgery2026',
      itemCount: 38,
      opCount: 1204,
      openedAtMs: 0,
      safetyClass: CapabilitySafetyClass.health,
    );

    expect(context.itemCount, 38);
    expect(context.label, startsWith('#'));
  });

  test('a peer that has never synced is behind by its whole log', () {
    const peer = MindPeer(
      deviceName: 'iPad Air',
      fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
      liveness: PeerLiveness.stale,
      opsBehind: 14,
      lastSeenMs: 0,
    );

    expect(peer.opsBehind, 14);
    expect(peer.fingerprint.toString(), '81DD · 4A05 · 7712');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/runtime/models_test.dart`

Expected: FAIL — "Undefined name 'MindOp'" and similar for every type.

- [ ] **Step 3: Write the log models**

Create `packages/feature_mind/lib/src/runtime/models/log_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// What kind of thing an operation records.
///
/// The Windows runtime console renders each of these differently, so this is
/// a closed set rather than a string: a new op kind must be a deliberate
/// change to the log's vocabulary, not a typo that renders as blank.
enum MindOpKind {
  note,
  scan,
  voice,
  transcript,
  inference,
  automation,
  merge,
  revoke,
  import,
}

/// Whether this operation's signature checked out.
///
/// `unverified` is not `unknown`. An op whose signature does not verify must
/// look different from one that does — that difference is the entire reason
/// the column exists.
enum SignatureState { verified, unverified, unsigned }

/// One entry in the append-only log.
///
/// [sequence] is the op number the whole product cites: the agent's answers
/// point at it, the inspector shows it, the console sorts by it.
@immutable
class MindOp {
  const MindOp({
    required this.sequence,
    required this.kind,
    required this.title,
    required this.contextId,
    required this.deviceName,
    required this.signature,
    required this.recordedAtMs,
    this.detail = '',
  });

  final int sequence;
  final MindOpKind kind;
  final String title;

  /// Empty for ops that belong to no context — a device revocation, for one.
  final String contextId;

  /// The device that wrote it, not the device reading it.
  final String deviceName;
  final SignatureState signature;
  final int recordedAtMs;

  /// The console's secondary line. Empty when there is nothing to add; never
  /// a duplicate of [title].
  final String detail;

  MindOp copyWith({SignatureState? signature}) => MindOp(
    sequence: sequence,
    kind: kind,
    title: title,
    contextId: contextId,
    deviceName: deviceName,
    signature: signature ?? this.signature,
    recordedAtMs: recordedAtMs,
    detail: detail,
  );

  @override
  bool operator ==(Object other) =>
      other is MindOp &&
      other.sequence == sequence &&
      other.kind == kind &&
      other.title == title &&
      other.contextId == contextId &&
      other.deviceName == deviceName &&
      other.signature == signature &&
      other.recordedAtMs == recordedAtMs &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(
    sequence,
    kind,
    title,
    contextId,
    deviceName,
    signature,
    recordedAtMs,
    detail,
  );
}
```

- [ ] **Step 4: Write the vault and mesh models**

Create `packages/feature_mind/lib/src/runtime/models/vault_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// A device key, shown to a person three groups at a time.
///
/// Grouped because a person compares these by eye during pairing, and an
/// unbroken hex run is the one format they cannot compare reliably.
@immutable
class DeviceFingerprint {
  const DeviceFingerprint(this.a, this.b, this.c);

  final String a;
  final String b;
  final String c;

  @override
  String toString() => '$a · $b · $c';

  @override
  bool operator ==(Object other) =>
      other is DeviceFingerprint &&
      other.a == a &&
      other.b == b &&
      other.c == c;

  @override
  int get hashCode => Object.hash(a, b, c);
}

/// A device that is, or was, authorised against this vault.
///
/// Revoked devices stay in the list. They are evidence, and a device that
/// vanishes on revocation cannot be distinguished from one that never existed.
@immutable
class MindDevice {
  const MindDevice({
    required this.name,
    required this.fingerprint,
    required this.isThisDevice,
    required this.revokedAtMs,
  });

  final String name;
  final DeviceFingerprint fingerprint;
  final bool isThisDevice;

  /// Null while authorised.
  final int? revokedAtMs;

  bool get isRevoked => revokedAtMs != null;

  @override
  bool operator ==(Object other) =>
      other is MindDevice &&
      other.name == name &&
      other.fingerprint == fingerprint &&
      other.isThisDevice == isThisDevice &&
      other.revokedAtMs == revokedAtMs;

  @override
  int get hashCode => Object.hash(name, fingerprint, isThisDevice, revokedAtMs);
}

/// The vault's state as a surface needs to render it.
///
/// [revocationEpoch] is monotonic; a peer presenting a lower epoch is stale
/// and its ops are not trusted until it catches up.
@immutable
class VaultState {
  const VaultState({
    required this.isSealed,
    required this.keyCount,
    required this.revokedCount,
    required this.revocationEpoch,
    required this.onDiskBytes,
  });

  final bool isSealed;
  final int keyCount;
  final int revokedCount;
  final int revocationEpoch;
  final int onDiskBytes;

  @override
  bool operator ==(Object other) =>
      other is VaultState &&
      other.isSealed == isSealed &&
      other.keyCount == keyCount &&
      other.revokedCount == revokedCount &&
      other.revocationEpoch == revocationEpoch &&
      other.onDiskBytes == onDiskBytes;

  @override
  int get hashCode =>
      Object.hash(isSealed, keyCount, revokedCount, revocationEpoch, onDiskBytes);
}
```

Create `packages/feature_mind/lib/src/runtime/models/mesh_models.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'vault_models.dart';

/// Whether a peer is reachable right now.
///
/// `stale` is a peer we know and have not heard from. `offline` is one that
/// declared itself gone. The devices surface renders them differently because
/// only one of them is a problem.
enum PeerLiveness { live, stale, offline }

/// A peer on the local network.
@immutable
class MindPeer {
  const MindPeer({
    required this.deviceName,
    required this.fingerprint,
    required this.liveness,
    required this.opsBehind,
    required this.lastSeenMs,
  });

  final String deviceName;
  final DeviceFingerprint fingerprint;
  final PeerLiveness liveness;

  /// How many ops this peer has not yet received. Zero means in sync.
  ///
  /// Surfaces show this number rather than the word "syncing", because a
  /// number tells a person whether to wait.
  final int opsBehind;
  final int lastSeenMs;

  @override
  bool operator ==(Object other) =>
      other is MindPeer &&
      other.deviceName == deviceName &&
      other.fingerprint == fingerprint &&
      other.liveness == liveness &&
      other.opsBehind == opsBehind &&
      other.lastSeenMs == lastSeenMs;

  @override
  int get hashCode =>
      Object.hash(deviceName, fingerprint, liveness, opsBehind, lastSeenMs);
}

/// A device asking to join the vault, with the code the two screens compare.
@immutable
class PairingRequest {
  const PairingRequest({
    required this.deviceName,
    required this.code,
    required this.requestedAtMs,
  });

  final String deviceName;

  /// Six digits. Shown on both devices; a person authorises by matching them.
  final String code;
  final int requestedAtMs;

  @override
  bool operator ==(Object other) =>
      other is PairingRequest &&
      other.deviceName == deviceName &&
      other.code == code &&
      other.requestedAtMs == requestedAtMs;

  @override
  int get hashCode => Object.hash(deviceName, code, requestedAtMs);
}
```

- [ ] **Step 5: Write the remaining five model files**

Create `packages/feature_mind/lib/src/runtime/models/capability_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// What a capability is allowed to claim, and therefore what warning its
/// surfaces must carry.
///
/// The Agent Chat safety banner is driven by this, not hardcoded per screen —
/// a health capability gets the wellness-only notice wherever it appears.
enum CapabilitySafetyClass { general, health, financial, legal }

/// An installed capability pack.
@immutable
class InstalledCapability {
  const InstalledCapability({
    required this.id,
    required this.name,
    required this.version,
    required this.isFirstParty,
    required this.isActive,
    required this.itemCount,
    required this.safetyClass,
    this.requiresConsentFor = const [],
  });

  final String id;
  final String name;
  final String version;
  final bool isFirstParty;
  final bool isActive;
  final int itemCount;
  final CapabilitySafetyClass safetyClass;

  /// Resources this pack cannot touch without an explicit consent gate —
  /// `mic` for Audio Scribe. Printed on the row, never buried in a sheet.
  final List<String> requiresConsentFor;

  @override
  bool operator ==(Object other) =>
      other is InstalledCapability &&
      other.id == id &&
      other.name == name &&
      other.version == version &&
      other.isFirstParty == isFirstParty &&
      other.isActive == isActive &&
      other.itemCount == itemCount &&
      other.safetyClass == safetyClass &&
      listEquals(other.requiresConsentFor, requiresConsentFor);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    version,
    isFirstParty,
    isActive,
    itemCount,
    safetyClass,
    Object.hashAll(requiresConsentFor),
  );
}
```

Create `packages/feature_mind/lib/src/runtime/models/context_models.dart`:

```dart
import 'package:flutter/foundation.dart';

import 'capability_models.dart';

/// A context in the hypergraph.
///
/// [opCount] and [itemCount] differ and both are shown: 38 items took 1,204
/// ops to reach. The gap is what makes the log's existence visible.
@immutable
class MindContext {
  const MindContext({
    required this.id,
    required this.label,
    required this.itemCount,
    required this.opCount,
    required this.openedAtMs,
    required this.safetyClass,
  });

  final String id;

  /// Includes the leading `#`. Surfaces render this verbatim.
  final String label;
  final int itemCount;
  final int opCount;
  final int openedAtMs;
  final CapabilitySafetyClass safetyClass;

  @override
  bool operator ==(Object other) =>
      other is MindContext &&
      other.id == id &&
      other.label == label &&
      other.itemCount == itemCount &&
      other.opCount == opCount &&
      other.openedAtMs == openedAtMs &&
      other.safetyClass == safetyClass;

  @override
  int get hashCode =>
      Object.hash(id, label, itemCount, opCount, openedAtMs, safetyClass);
}

/// An edge in the hypergraph. Undirected: linking A to B links B to A.
@immutable
class ContextLink {
  const ContextLink(this.fromId, this.toId);

  final String fromId;
  final String toId;

  @override
  bool operator ==(Object other) =>
      other is ContextLink &&
      ((other.fromId == fromId && other.toId == toId) ||
          (other.fromId == toId && other.toId == fromId));

  @override
  int get hashCode => fromId.hashCode ^ toId.hashCode;
}
```

Create `packages/feature_mind/lib/src/runtime/models/projection_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// The three projections. There are exactly three and they are one switcher —
/// see rule R03.
enum ProjectionKind { graph, timeline, search }

/// Where a projection is in its rebuild cycle.
///
/// Three projections can be in three different states for the same op, and
/// the inspector must say so rather than reporting one summary state.
enum ProjectionStatus { fresh, rebuilding, queued, stale }

/// A projection's state, including how long its last rebuild actually took.
///
/// [lastRebuildMs] is measured, not configured. Surfaces print it ("REBUILT
/// 3.1S AGO"), so a made-up number is a false claim on screen.
@immutable
class ProjectionState {
  const ProjectionState({
    required this.kind,
    required this.status,
    required this.lastRebuildMs,
    required this.opsProcessed,
    required this.opsTotal,
  });

  final ProjectionKind kind;
  final ProjectionStatus status;
  final int lastRebuildMs;

  /// Drives the rebuilding state's progress. A spinner without these two is
  /// a rule R04 violation.
  final int opsProcessed;
  final int opsTotal;

  @override
  bool operator ==(Object other) =>
      other is ProjectionState &&
      other.kind == kind &&
      other.status == status &&
      other.lastRebuildMs == lastRebuildMs &&
      other.opsProcessed == opsProcessed &&
      other.opsTotal == opsTotal;

  @override
  int get hashCode =>
      Object.hash(kind, status, lastRebuildMs, opsProcessed, opsTotal);
}

/// A search result, pointing back at the op it came from.
@immutable
class SearchHitRef {
  const SearchHitRef({
    required this.opSequence,
    required this.title,
    required this.snippet,
    required this.contextIds,
  });

  final int opSequence;
  final String title;
  final String snippet;
  final List<String> contextIds;

  @override
  bool operator ==(Object other) =>
      other is SearchHitRef &&
      other.opSequence == opSequence &&
      other.title == title &&
      other.snippet == snippet &&
      listEquals(other.contextIds, contextIds);

  @override
  int get hashCode =>
      Object.hash(opSequence, title, snippet, Object.hashAll(contextIds));
}
```

Create `packages/feature_mind/lib/src/runtime/models/model_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Whether a model is in memory, on disk, or neither.
///
/// Three states, not two. `resident` means a capability holds it on disk —
/// evicting it breaks that capability, and the surface must name which.
enum ModelResidency { loaded, resident, available }

/// Thermal state at the moment a benchmark was taken.
///
/// Carried alongside the benchmark because a tok/s figure measured cold and
/// displayed while throttled is a false claim.
enum ThermalState { nominal, fair, serious, critical }

/// Numbers measured on this hardware. Never a spec sheet figure.
@immutable
class ModelBench {
  const ModelBench({
    required this.tokensPerSecond,
    required this.firstTokenMs,
    required this.residentBytes,
    required this.batteryPercentPerHour,
    required this.measuredUnder,
    required this.measuredAtMs,
  });

  final double tokensPerSecond;
  final int firstTokenMs;
  final int residentBytes;
  final double batteryPercentPerHour;
  final ThermalState measuredUnder;
  final int measuredAtMs;

  @override
  bool operator ==(Object other) =>
      other is ModelBench &&
      other.tokensPerSecond == tokensPerSecond &&
      other.firstTokenMs == firstTokenMs &&
      other.residentBytes == residentBytes &&
      other.batteryPercentPerHour == batteryPercentPerHour &&
      other.measuredUnder == measuredUnder &&
      other.measuredAtMs == measuredAtMs;

  @override
  int get hashCode => Object.hash(
    tokensPerSecond,
    firstTokenMs,
    residentBytes,
    batteryPercentPerHour,
    measuredUnder,
    measuredAtMs,
  );
}

/// A model on, or available to, this device.
@immutable
class MindModel {
  const MindModel({
    required this.id,
    required this.name,
    required this.sizeBytes,
    required this.residency,
    this.heldBy = '',
    this.bench,
  });

  final String id;
  final String name;
  final int sizeBytes;
  final ModelResidency residency;

  /// The capability holding this model resident. Empty unless
  /// [residency] is [ModelResidency.resident].
  final String heldBy;

  /// Null until measured. A surface must not show a benchmark that has never
  /// been run.
  final ModelBench? bench;

  @override
  bool operator ==(Object other) =>
      other is MindModel &&
      other.id == id &&
      other.name == name &&
      other.sizeBytes == sizeBytes &&
      other.residency == residency &&
      other.heldBy == heldBy &&
      other.bench == bench;

  @override
  int get hashCode =>
      Object.hash(id, name, sizeBytes, residency, heldBy, bench);
}
```

Create `packages/feature_mind/lib/src/runtime/models/portability_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Where a sealed package can go. None of these is a server, because there
/// isn't one.
enum PackageDestination { lanPeer, thisDevice, usbDrive }

/// One band of the size breakdown — scans, audio, log.
@immutable
class ContentClassSize {
  const ContentClassSize(this.label, this.bytes);

  final String label;
  final int bytes;

  @override
  bool operator ==(Object other) =>
      other is ContentClassSize && other.label == label && other.bytes == bytes;

  @override
  int get hashCode => Object.hash(label, bytes);
}

/// What sealing would produce, given the contexts currently selected.
///
/// Recomputed on every selection change: a size that does not move when a
/// context is unchecked tells the person their choice did nothing.
@immutable
class RecoveryPackagePlan {
  const RecoveryPackagePlan({
    required this.selectedContextIds,
    required this.breakdown,
    required this.fileName,
  });

  final List<String> selectedContextIds;
  final List<ContentClassSize> breakdown;
  final String fileName;

  int get totalBytes =>
      breakdown.fold(0, (sum, class_) => sum + class_.bytes);

  @override
  bool operator ==(Object other) =>
      other is RecoveryPackagePlan &&
      listEquals(other.selectedContextIds, selectedContextIds) &&
      listEquals(other.breakdown, breakdown) &&
      other.fileName == fileName;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(selectedContextIds),
    Object.hashAll(breakdown),
    fileName,
  );
}
```

- [ ] **Step 6: Export the models**

Add to `packages/feature_mind/lib/feature_mind.dart`, below the existing exports:

```dart
export 'src/runtime/models/capability_models.dart';
export 'src/runtime/models/context_models.dart';
export 'src/runtime/models/log_models.dart';
export 'src/runtime/models/mesh_models.dart';
export 'src/runtime/models/model_models.dart';
export 'src/runtime/models/portability_models.dart';
export 'src/runtime/models/projection_models.dart';
export 'src/runtime/models/vault_models.dart';
```

- [ ] **Step 7: Run the test**

Run: `cd packages/feature_mind && flutter test test/runtime/models_test.dart`

Expected: PASS, 4 tests.

- [ ] **Step 8: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): add the runtime's domain models

Eight files, one per port, hand-written rather than generated: these are
the frozen contract and a code generator's output is not a contract.

Refs #1449"
```

---

### Task 3: The eight sub-ports and the `MindRuntime` aggregate

The contract itself. Every method is one a surface actually calls; nothing is added speculatively.

`MindPortUnavailable` is how a partial implementation says so. It names the sub-port, because "Mind is unavailable" tells a person nothing and "the mesh is not implemented yet" tells them the rest of the app works.

**Files:**
- Create: `packages/feature_mind/lib/src/runtime/ports/vault_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/operation_log_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/context_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/projection_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/mesh_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/capability_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/model_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/ports/portability_port.dart`
- Create: `packages/feature_mind/lib/src/runtime/mind_runtime.dart`
- Test: `packages/feature_mind/test/runtime/mind_runtime_test.dart`

**Interfaces:**
- Consumes: every model from Task 2.
- Produces: `MindRuntime` with getters `vault`, `log`, `contexts`, `projections`, `mesh`, `capabilities`, `models`, `portability`; the eight abstract port classes; `MindPortUnavailable(String port, String reason)`.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/runtime/mind_runtime_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MindPortUnavailable names the port, not just the product', () {
    const failure = MindPortUnavailable('MeshPort', 'peer discovery is #1200');

    expect(failure.port, 'MeshPort');
    expect(failure.toString(), contains('MeshPort'));
    expect(failure.toString(), contains('#1200'));
  });

  test('MindRuntime exposes exactly the eight sub-ports', () {
    // A ninth port is an architecture change, not an implementation detail:
    // the freeze permits new capabilities, not new runtime surfaces.
    const expected = {
      'vault',
      'log',
      'contexts',
      'projections',
      'mesh',
      'capabilities',
      'models',
      'portability',
    };

    expect(MindRuntime.portNames, equals(expected));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/runtime/mind_runtime_test.dart`

Expected: FAIL — "Undefined name 'MindPortUnavailable'".

- [ ] **Step 3: Write the four read-heavy ports**

Create `packages/feature_mind/lib/src/runtime/ports/vault_port.dart`:

```dart
import '../models/vault_models.dart';

/// Root identity, device keys, and revocation.
///
/// Read-only from the surfaces' point of view except for [revokeDevice] —
/// authorising and revoking are the only two writes a person makes here, and
/// both are deliberate acts with their own confirmation.
abstract interface class VaultPort {
  Future<VaultState> state();

  /// Authorised devices, revoked ones included. Revoked devices are evidence
  /// and stay in the list.
  Future<List<MindDevice>> devices();

  /// Revokes every key held by [fingerprint] at once.
  ///
  /// O(contexts), never O(content): the wrapping keys are re-wrapped, the
  /// ciphertext is untouched.
  Future<void> revokeDevice(DeviceFingerprint fingerprint);
}
```

Create `packages/feature_mind/lib/src/runtime/ports/operation_log_port.dart`:

```dart
import '../models/log_models.dart';

/// The append-only log.
///
/// [range] rather than a bare list: the Windows console renders a table over
/// 12,000+ ops and must not load them all to show nine.
abstract interface class OperationLogPort {
  Future<int> count();

  /// Ops in descending sequence, newest first, starting at [offset].
  Future<List<MindOp>> range({required int offset, required int limit});

  Future<MindOp?> bySequence(int sequence);

  /// Appends a signed op and returns its sequence number.
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail,
  });

  /// Re-verifies a signature against the device certificate that claims it.
  ///
  /// Separate from reading the op because the console shows the stored state
  /// and lets a person demand a fresh check on one row.
  Future<SignatureState> verify(int sequence);

  /// Replays the log from [sequence] forward, rebuilding projections.
  Stream<double> replayFrom(int sequence);
}
```

Create `packages/feature_mind/lib/src/runtime/ports/context_port.dart`:

```dart
import '../models/context_models.dart';

/// The hypergraph.
abstract interface class ContextPort {
  Future<List<MindContext>> all();

  Future<MindContext?> byId(String id);

  Future<List<ContextLink>> linksFor(String contextId);

  Future<MindContext> create({required String label});

  Future<void> link(String fromId, String toId);

  Future<void> unlink(String fromId, String toId);

  /// What would survive if [contextId] were destroyed.
  ///
  /// Returned before the destroy, not after: the survival preview is the whole
  /// difference between unlinking and shredding, and a person must see it
  /// while the choice is still theirs.
  Future<List<String>> survivorsIfDestroyed(String contextId);
}
```

Create `packages/feature_mind/lib/src/runtime/ports/projection_port.dart`:

```dart
import '../models/projection_models.dart';

/// Graph, timeline and search — three views of one log.
///
/// Projections are disposable. Deleting an index must genuinely rebuild it,
/// which is why [rebuild] reports real progress rather than resolving instantly.
abstract interface class ProjectionPort {
  Future<ProjectionState> stateOf(ProjectionKind kind);

  /// All three at once. They can be in three different states and the
  /// inspector shows each independently.
  Future<List<ProjectionState>> states();

  Stream<ProjectionState> rebuild(ProjectionKind kind);

  /// Ranked locally by embedding plus keyword. The surface prints the hit
  /// count and the latency, so both are returned rather than inferred.
  Future<List<SearchHitRef>> search(String query, {String? contextId});
}
```

- [ ] **Step 4: Write the four remaining ports**

Create `packages/feature_mind/lib/src/runtime/ports/mesh_port.dart`:

```dart
import '../models/mesh_models.dart';
import '../models/vault_models.dart';

/// Peer discovery and pairing over the local network. No relay, no account.
abstract interface class MeshPort {
  Stream<List<MindPeer>> peers();

  Stream<PairingRequest?> pendingRequest();

  Future<void> authorise(PairingRequest request);

  Future<void> deny(PairingRequest request);

  /// Pushes queued ops to one peer. Returns ops remaining when it settles.
  Future<int> push(DeviceFingerprint peer);
}
```

Create `packages/feature_mind/lib/src/runtime/ports/capability_port.dart`:

```dart
import '../models/capability_models.dart';

/// Installed capability packs. Packs are declarative data, not code.
///
/// There is no `install` here. Acquiring a pack is milestone 20's marketplace;
/// this port manages what is already on the device.
abstract interface class CapabilityPort {
  Future<List<InstalledCapability>> installed();

  Future<InstalledCapability?> byId(String id);

  Future<void> setActive(String id, {required bool active});

  /// Removes the pack. Contexts it created survive — removing a capability
  /// must not remove a person's data.
  Future<void> remove(String id);
}
```

Create `packages/feature_mind/lib/src/runtime/ports/model_port.dart`:

```dart
import '../models/model_models.dart';

/// On-device models: what is loaded, what is held, what could be fetched.
abstract interface class ModelPort {
  Future<List<MindModel>> all();

  /// Bytes used and bytes available for models on this device.
  Future<({int usedBytes, int budgetBytes})> storage();

  Future<void> load(String modelId);

  /// Fails rather than silently breaking a capability that holds the model
  /// resident. The error names that capability.
  Future<void> unload(String modelId);

  /// Emits bytes downloaded of total. Pauses on metered connections; the
  /// stream stalls rather than erroring, and resumes when unmetered.
  Stream<({int received, int total})> download(String modelId);

  /// Measures on this hardware. Never returns a spec-sheet figure.
  Future<ModelBench> benchmark(String modelId);

  /// Emits on every thermal transition, which is the trigger to re-benchmark.
  Stream<ThermalState> thermal();
}
```

Create `packages/feature_mind/lib/src/runtime/ports/portability_port.dart`:

```dart
import '../models/portability_models.dart';

/// Recovery Package export.
///
/// The package format is fixed by the architecture freeze and issue #1305.
/// This port is the export flow only.
abstract interface class PortabilityPort {
  /// What sealing would produce for [contextIds]. Recomputed per selection.
  Future<RecoveryPackagePlan> plan(List<String> contextIds);

  /// Seals and writes. Emits bytes written of total.
  ///
  /// [passphrase] is not stored anywhere. If it is lost the package cannot be
  /// opened, and there is no reset — the surface says so before this is called.
  Stream<({int written, int total})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  });
}
```

- [ ] **Step 5: Write the aggregate**

Create `packages/feature_mind/lib/src/runtime/mind_runtime.dart`:

```dart
import 'ports/capability_port.dart';
import 'ports/context_port.dart';
import 'ports/mesh_port.dart';
import 'ports/model_port.dart';
import 'ports/operation_log_port.dart';
import 'ports/portability_port.dart';
import 'ports/projection_port.dart';
import 'ports/vault_port.dart';

/// One sub-port is not implemented on this runtime yet.
///
/// Names the port rather than the product. "Airo Mind is unavailable" tells a
/// person nothing; "the mesh is not implemented yet" tells them the rest of
/// the app works, which is true and useful while milestone 19 lands.
class MindPortUnavailable implements Exception {
  const MindPortUnavailable(this.port, this.reason);

  final String port;
  final String reason;

  @override
  String toString() => 'MindPortUnavailable: $port — $reason';
}

/// Everything a Mind surface is allowed to do.
///
/// Eight sub-ports rather than one wide interface so a screen depends on the
/// slice it uses. The Devices screen takes a [MeshPort] and a [VaultPort]; it
/// has no way to reach the model downloader.
///
/// This is the contract milestone 19 implements against. A runtime that cannot
/// satisfy a method here files an ADR — it does not quietly reshape the port.
abstract interface class MindRuntime {
  /// The eight names, for the conformance test that guards against a ninth.
  static const Set<String> portNames = {
    'vault',
    'log',
    'contexts',
    'projections',
    'mesh',
    'capabilities',
    'models',
    'portability',
  };

  VaultPort get vault;
  OperationLogPort get log;
  ContextPort get contexts;
  ProjectionPort get projections;
  MeshPort get mesh;
  CapabilityPort get capabilities;
  ModelPort get models;
  PortabilityPort get portability;
}
```

- [ ] **Step 6: Export the runtime**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/runtime/mind_runtime.dart';
export 'src/runtime/ports/capability_port.dart';
export 'src/runtime/ports/context_port.dart';
export 'src/runtime/ports/mesh_port.dart';
export 'src/runtime/ports/model_port.dart';
export 'src/runtime/ports/operation_log_port.dart';
export 'src/runtime/ports/portability_port.dart';
export 'src/runtime/ports/projection_port.dart';
export 'src/runtime/ports/vault_port.dart';
```

- [ ] **Step 7: Run the test**

Run: `cd packages/feature_mind && flutter test test/runtime/mind_runtime_test.dart`

Expected: PASS, 2 tests.

- [ ] **Step 8: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): freeze the MindRuntime port in eight sub-ports

The contract milestone 19 implements against. Eight sub-ports rather
than one wide interface so a screen depends only on the slice it uses.
MindPortUnavailable names the missing port, because 'Mind is
unavailable' tells a person nothing while M19 is partial.

Refs #1449"
```

---

### Task 4: `FixtureMindRuntime` — vault, log, contexts

Deterministic. Seeded with the design's own numbers so that a screenshot of the fixture and a screenshot of the design show the same thing, and a golden test can hold either to account.

No `DateTime.now()` and no randomness anywhere in the fixture. A golden that changes with the clock is a golden that gets deleted.

**Files:**
- Create: `packages/feature_mind/lib/src/runtime/fixture/fixture_data.dart`
- Create: `packages/feature_mind/lib/src/runtime/fixture/fixture_mind_runtime.dart`
- Test: `packages/feature_mind/test/runtime/fixture_mind_runtime_test.dart`

**Interfaces:**
- Consumes: the ports and models from Tasks 2–3.
- Produces: `FixtureMindRuntime()`, `const FixtureMindRuntime.frozen()`, and the `fixtureContexts` / `fixtureOps` / `fixtureDevices` / `fixturePeers` constants. Task 5 extends the same class; Tasks 7–12 use it as the test double.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/runtime/fixture_mind_runtime_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixtureMindRuntime runtime;

  setUp(() => runtime = FixtureMindRuntime());

  test('carries the design numbers so a golden can hold them to account',
      () async {
    expect(await runtime.log.count(), 12481);

    final contexts = await runtime.contexts.all();
    expect(contexts.map((c) => c.label), [
      '#KneeSurgery2026',
      '#DowntownApartment',
      '#Q3TaxFiling',
      '#AiroArchitecture',
    ]);
    expect(contexts.map((c) => c.itemCount), [38, 17, 52, 9]);
  });

  test('is deterministic across instances', () async {
    final first = await FixtureMindRuntime().log.range(offset: 0, limit: 5);
    final second = await FixtureMindRuntime().log.range(offset: 0, limit: 5);

    expect(first, equals(second));
  });

  test('the log reads newest first and pages', () async {
    final page = await runtime.log.range(offset: 0, limit: 3);

    expect(page.first.sequence, 12481);
    expect(page.length, 3);
    expect(
      page.map((op) => op.sequence),
      orderedEquals([12481, 12477, 12463]),
    );
  });

  test('appending advances the sequence and is readable back', () async {
    final before = await runtime.log.count();

    final sequence = await runtime.log.append(
      kind: MindOpKind.note,
      title: 'Carrier 24V filter — order two before the fifteenth',
      contextId: 'downtownapartment',
    );

    expect(sequence, before + 1);
    final op = await runtime.log.bySequence(sequence);
    expect(op?.title, contains('Carrier 24V'));
    expect(op?.signature, SignatureState.verified);
  });

  test('the vault reports one revoked device and keeps it listed', () async {
    final state = await runtime.vault.state();
    expect(state.isSealed, isTrue);
    expect(state.keyCount, 4);
    expect(state.revokedCount, 1);

    final devices = await runtime.vault.devices();
    expect(devices.where((d) => d.isRevoked).map((d) => d.name), ['MacBook · Old']);
    expect(devices.singleWhere((d) => d.isThisDevice).name, 'Pixel 9 Pro');
  });

  test('destroying a context previews what survives', () async {
    final survivors = await runtime.contexts.survivorsIfDestroyed(
      'kneesurgery2026',
    );

    // The discharge note is linked into tax filing too, so it survives.
    expect(survivors, contains('#Q3TaxFiling'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/runtime/fixture_mind_runtime_test.dart`

Expected: FAIL — "Undefined name 'FixtureMindRuntime'".

- [ ] **Step 3: Write the fixture data**

Create `packages/feature_mind/lib/src/runtime/fixture/fixture_data.dart`:

```dart
import '../models/capability_models.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/mesh_models.dart';
import '../models/vault_models.dart';

/// The design's own numbers, verbatim.
///
/// Fixed timestamps, no clock, no randomness: a golden that moves with the
/// wall clock is a golden that gets deleted. Every value here appears in
/// `Airo Mind Device System.dc.html`, so a fixture screenshot and the design
/// show the same thing.

/// 2026-08-01T07:12:04Z, the design's "today".
const int fixtureNowMs = 1785827524000;

const _day = 86400000;

const List<MindContext> fixtureContexts = [
  MindContext(
    id: 'kneesurgery2026',
    label: '#KneeSurgery2026',
    itemCount: 38,
    opCount: 1204,
    openedAtMs: fixtureNowMs - 50 * _day,
    safetyClass: CapabilitySafetyClass.health,
  ),
  MindContext(
    id: 'downtownapartment',
    label: '#DowntownApartment',
    itemCount: 17,
    opCount: 402,
    openedAtMs: fixtureNowMs - 120 * _day,
    safetyClass: CapabilitySafetyClass.general,
  ),
  MindContext(
    id: 'q3taxfiling',
    label: '#Q3TaxFiling',
    itemCount: 52,
    opCount: 918,
    openedAtMs: fixtureNowMs - 90 * _day,
    safetyClass: CapabilitySafetyClass.financial,
  ),
  MindContext(
    id: 'airoarchitecture',
    label: '#AiroArchitecture',
    itemCount: 9,
    opCount: 143,
    openedAtMs: fixtureNowMs - 20 * _day,
    safetyClass: CapabilitySafetyClass.general,
  ),
];

/// The discharge note is linked into both health and tax, which is what makes
/// the survival preview non-trivial.
const List<ContextLink> fixtureLinks = [
  ContextLink('kneesurgery2026', 'q3taxfiling'),
  ContextLink('downtownapartment', 'q3taxfiling'),
];

/// The nine ops the Windows console shows, newest first.
const List<MindOp> fixtureOps = [
  MindOp(
    sequence: 12481,
    kind: MindOpKind.automation,
    title: 'Ibuprofen 400 mg logged',
    contextId: 'kneesurgery2026',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs,
    detail: 'Capability · Hospital Recovery · automation fired on schedule',
  ),
  MindOp(
    sequence: 12477,
    kind: MindOpKind.scan,
    title: 'Bank statement · July, page 2',
    contextId: 'q3taxfiling',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 800000,
  ),
  MindOp(
    sequence: 12463,
    kind: MindOpKind.merge,
    title: 'Physio plan · week 4 — merged from 2 devices',
    contextId: 'kneesurgery2026',
    deviceName: 'iPad Air',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - _day,
  ),
  MindOp(
    sequence: 12455,
    kind: MindOpKind.inference,
    title: 'Summarised 3 physio notes · Gemma 3n · 2.1 s',
    contextId: 'kneesurgery2026',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - _day - 3600000,
  ),
  MindOp(
    sequence: 12388,
    kind: MindOpKind.scan,
    title: 'Invoice · Kitchen repair, Basu Contracting',
    contextId: 'q3taxfiling',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 4 * _day,
  ),
  MindOp(
    sequence: 12341,
    kind: MindOpKind.voice,
    title: '"Call the contractor back" · 0:14',
    contextId: 'downtownapartment',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 6 * _day,
  ),
  MindOp(
    sequence: 12290,
    kind: MindOpKind.revoke,
    title: 'Key revoked · old laptop removed from mesh',
    contextId: '',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 10 * _day,
  ),
  MindOp(
    sequence: 12214,
    kind: MindOpKind.import,
    title: 'Email export · quote revision 2',
    contextId: 'downtownapartment',
    deviceName: 'Desktop',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 14 * _day,
  ),
  MindOp(
    sequence: 12150,
    kind: MindOpKind.scan,
    title: 'Receipt · hardware store, tiles',
    contextId: 'q3taxfiling',
    deviceName: 'Pixel 9 Pro',
    signature: SignatureState.verified,
    recordedAtMs: fixtureNowMs - 18 * _day,
  ),
];

const List<MindDevice> fixtureDevices = [
  MindDevice(
    name: 'Pixel 9 Pro',
    fingerprint: DeviceFingerprint('4F2A', '9C71', 'E0B3'),
    isThisDevice: true,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'iPad Air · Studio',
    fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
    isThisDevice: false,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'Fold 6 · Pocket',
    fingerprint: DeviceFingerprint('C0F9', '22B8', '5E4D'),
    isThisDevice: false,
    revokedAtMs: null,
  ),
  MindDevice(
    name: 'MacBook · Old',
    fingerprint: DeviceFingerprint('A731', '0C4E', '9982'),
    isThisDevice: false,
    revokedAtMs: fixtureNowMs - 28 * _day,
  ),
];

const List<MindPeer> fixturePeers = [
  MindPeer(
    deviceName: 'iPad Air · Studio',
    fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
    liveness: PeerLiveness.live,
    opsBehind: 0,
    lastSeenMs: fixtureNowMs - 41000,
  ),
  MindPeer(
    deviceName: 'Fold 6 · Pocket',
    fingerprint: DeviceFingerprint('C0F9', '22B8', '5E4D'),
    liveness: PeerLiveness.stale,
    opsBehind: 14,
    lastSeenMs: fixtureNowMs - 6 * 3600000,
  ),
  MindPeer(
    deviceName: 'Home NAS',
    fingerprint: DeviceFingerprint('5B10', 'EE33', '0147'),
    liveness: PeerLiveness.offline,
    opsBehind: 212,
    lastSeenMs: fixtureNowMs - 3 * _day,
  ),
];

const PairingRequest fixturePairingRequest = PairingRequest(
  deviceName: 'Pixel Watch 3',
  code: '492716',
  requestedAtMs: fixtureNowMs - 30000,
);
```

- [ ] **Step 4: Write the fixture runtime's first three ports**

Create `packages/feature_mind/lib/src/runtime/fixture/fixture_mind_runtime.dart`:

```dart
import '../mind_runtime.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/vault_models.dart';
import '../ports/capability_port.dart';
import '../ports/context_port.dart';
import '../ports/mesh_port.dart';
import '../ports/model_port.dart';
import '../ports/operation_log_port.dart';
import '../ports/portability_port.dart';
import '../ports/projection_port.dart';
import '../ports/vault_port.dart';
import 'fixture_data.dart';

/// A runtime that behaves like the real one and stores nothing.
///
/// Every surface is built and golden-tested against this while milestone 19
/// lands the real thing. It is not a mock: appending really does advance the
/// sequence, rebuilding really does take time, and a search really does filter.
/// A double that resolves everything instantly would let a surface ship that
/// has never rendered a loading state.
class FixtureMindRuntime implements MindRuntime {
  FixtureMindRuntime()
    : _log = _FixtureLog(),
      _contexts = _FixtureContexts(),
      _vault = const _FixtureVault();

  final _FixtureLog _log;
  final _FixtureContexts _contexts;
  final _FixtureVault _vault;

  @override
  VaultPort get vault => _vault;

  @override
  OperationLogPort get log => _log;

  @override
  ContextPort get contexts => _contexts;

  // Ports filled in by Task 5.
  @override
  ProjectionPort get projections => throw UnimplementedError();

  @override
  MeshPort get mesh => throw UnimplementedError();

  @override
  CapabilityPort get capabilities => throw UnimplementedError();

  @override
  ModelPort get models => throw UnimplementedError();

  @override
  PortabilityPort get portability => throw UnimplementedError();
}

class _FixtureVault implements VaultPort {
  const _FixtureVault();

  @override
  Future<VaultState> state() async => const VaultState(
    isSealed: true,
    keyCount: 4,
    revokedCount: 1,
    revocationEpoch: 3,
    onDiskBytes: 14200000000,
  );

  @override
  Future<List<MindDevice>> devices() async => fixtureDevices;

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async {}
}

class _FixtureLog implements OperationLogPort {
  /// Appended ops live here. The 12,481 below them are implied: the fixture
  /// reports the real count and serves the nine the design shows, which is
  /// what every surface actually pages through.
  final List<MindOp> _appended = [];

  static const _baseCount = 12481;

  List<MindOp> get _all => [..._appended.reversed, ...fixtureOps];

  @override
  Future<int> count() async => _baseCount + _appended.length;

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async {
    final all = _all;
    if (offset >= all.length) return const [];
    return all.skip(offset).take(limit).toList(growable: false);
  }

  @override
  Future<MindOp?> bySequence(int sequence) async {
    for (final op in _all) {
      if (op.sequence == sequence) return op;
    }
    return null;
  }

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async {
    final sequence = await count() + 1;
    _appended.add(
      MindOp(
        sequence: sequence,
        kind: kind,
        title: title,
        contextId: contextId,
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        // Derived from the sequence, not the clock: two runs must produce the
        // same bytes or the goldens flake.
        recordedAtMs: fixtureNowMs + (sequence - _baseCount) * 1000,
        detail: detail,
      ),
    );
    return sequence;
  }

  @override
  Future<SignatureState> verify(int sequence) async =>
      (await bySequence(sequence))?.signature ?? SignatureState.unsigned;

  @override
  Stream<double> replayFrom(int sequence) async* {
    for (var step = 0; step <= 10; step++) {
      yield step / 10;
    }
  }
}

class _FixtureContexts implements ContextPort {
  final List<MindContext> _created = [];

  @override
  Future<List<MindContext>> all() async => [...fixtureContexts, ..._created];

  @override
  Future<MindContext?> byId(String id) async {
    for (final context in await all()) {
      if (context.id == id) return context;
    }
    return null;
  }

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => fixtureLinks
      .where((link) => link.fromId == contextId || link.toId == contextId)
      .toList(growable: false);

  @override
  Future<MindContext> create({required String label}) async {
    final context = MindContext(
      id: label.replaceAll('#', '').toLowerCase(),
      label: label,
      itemCount: 0,
      opCount: 1,
      openedAtMs: fixtureNowMs,
      safetyClass: fixtureContexts.first.safetyClass,
    );
    _created.add(context);
    return context;
  }

  @override
  Future<void> link(String fromId, String toId) async {}

  @override
  Future<void> unlink(String fromId, String toId) async {}

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async {
    final linked = await linksFor(contextId);
    final ids = linked
        .map((link) => link.fromId == contextId ? link.toId : link.fromId)
        .toSet();
    final all = await this.all();
    return all
        .where((context) => ids.contains(context.id))
        .map((context) => context.label)
        .toList(growable: false);
  }
}
```

- [ ] **Step 5: Export and run the test**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/runtime/fixture/fixture_data.dart';
export 'src/runtime/fixture/fixture_mind_runtime.dart';
```

Run: `cd packages/feature_mind && flutter test test/runtime/fixture_mind_runtime_test.dart`

Expected: PASS, 6 tests.

- [ ] **Step 6: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): fixture runtime for vault, log and contexts

Seeded with the design's own numbers so a fixture screenshot and the
design show the same thing. No clock and no randomness: a golden that
moves with the wall clock is a golden that gets deleted.

Refs #1449"
```

---

### Task 5: `FixtureMindRuntime` — projections, mesh, capabilities, models, portability

The five remaining ports. Two of them must not resolve instantly: `ProjectionPort.rebuild` takes the design's 3.1 seconds in wall-clock terms, and `ModelPort.download` emits partial progress — otherwise a surface can ship having never rendered its own loading state.

**Files:**
- Modify: `packages/feature_mind/lib/src/runtime/fixture/fixture_mind_runtime.dart`
- Modify: `packages/feature_mind/lib/src/runtime/fixture/fixture_data.dart`
- Test: `packages/feature_mind/test/runtime/fixture_ports_test.dart`

**Interfaces:**
- Consumes: Task 4's `FixtureMindRuntime`, all ports.
- Produces: the five remaining getters returning working fixtures, plus `fixtureCapabilities` and `fixtureModels` constants.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/runtime/fixture_ports_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FixtureMindRuntime runtime;

  setUp(() => runtime = FixtureMindRuntime());

  test('the three projections can be in three different states', () async {
    final states = await runtime.projections.states();

    expect(states.map((s) => s.kind), [
      ProjectionKind.graph,
      ProjectionKind.timeline,
      ProjectionKind.search,
    ]);
    expect(states.map((s) => s.status).toSet().length, greaterThan(1));
  });

  test('rebuild reports progress before it finishes', () async {
    final emitted = await runtime.projections
        .rebuild(ProjectionKind.search)
        .toList();

    expect(emitted.length, greaterThan(1));
    expect(emitted.first.status, ProjectionStatus.rebuilding);
    expect(emitted.last.status, ProjectionStatus.fresh);
    // The design prints "REBUILT 3.1S AGO"; the fixture must produce a real
    // number for that copy rather than letting the screen invent one.
    expect(emitted.last.lastRebuildMs, 3100);
  });

  test('search filters and points back at ops', () async {
    final hits = await runtime.projections.search('contractor');

    expect(hits, isNotEmpty);
    expect(hits.every((hit) => hit.opSequence > 0), isTrue);
    expect(
      hits.map((hit) => hit.title).join(' ').toLowerCase(),
      contains('contractor'),
    );
  });

  test('the mesh reports three peers with real ops-behind counts', () async {
    final peers = await runtime.mesh.peers().first;

    expect(peers.length, 3);
    expect(peers.map((p) => p.opsBehind), [0, 14, 212]);
  });

  test('a pending pairing request carries a six-digit code', () async {
    final request = await runtime.mesh.pendingRequest().first;

    expect(request?.code, hasLength(6));
    expect(request?.deviceName, 'Pixel Watch 3');
  });

  test('five capabilities are installed, one consent-gated', () async {
    final installed = await runtime.capabilities.installed();

    expect(installed.length, 5);
    final scribe = installed.singleWhere((c) => c.id == 'audio_scribe');
    expect(scribe.requiresConsentFor, contains('mic'));
  });

  test('removing a capability leaves its contexts alone', () async {
    final before = await runtime.contexts.all();
    await runtime.capabilities.remove('hospital_recovery');
    final after = await runtime.contexts.all();

    expect(after, equals(before));
  });

  test('models report three residencies and a real storage budget', () async {
    final models = await runtime.models.all();
    final storage = await runtime.models.storage();

    expect(
      models.map((m) => m.residency).toSet(),
      containsAll([
        ModelResidency.loaded,
        ModelResidency.resident,
        ModelResidency.available,
      ]),
    );
    expect(storage.usedBytes, lessThan(storage.budgetBytes));
  });

  test('unloading a resident model names the capability that breaks', () async {
    expect(
      () => runtime.models.unload('whisper_small'),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Audio Scribe'),
        ),
      ),
    );
  });

  test('a benchmark carries the thermal state it was measured under', () async {
    final bench = await runtime.models.benchmark('gemma_3n_e4b');

    expect(bench.tokensPerSecond, 24.1);
    expect(bench.measuredUnder, ThermalState.nominal);
  });

  test('a package plan shrinks when a context is unchecked', () async {
    final all = await runtime.portability.plan([
      'kneesurgery2026',
      'downtownapartment',
      'q3taxfiling',
      'airoarchitecture',
    ]);
    final fewer = await runtime.portability.plan(['kneesurgery2026']);

    expect(fewer.totalBytes, lessThan(all.totalBytes));
    expect(all.fileName, endsWith('.airobackup'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/runtime/fixture_ports_test.dart`

Expected: FAIL with `UnimplementedError` from the five stub getters.

- [ ] **Step 3: Add the capability and model fixture data**

Append to `packages/feature_mind/lib/src/runtime/fixture/fixture_data.dart`:

```dart
const List<InstalledCapability> fixtureCapabilities = [
  InstalledCapability(
    id: 'hospital_recovery',
    name: 'Hospital Recovery',
    version: '1.4',
    isFirstParty: true,
    isActive: true,
    itemCount: 38,
    safetyClass: CapabilitySafetyClass.health,
  ),
  InstalledCapability(
    id: 'property_maintenance',
    name: 'Property Maintenance',
    version: '0.9',
    isFirstParty: true,
    isActive: true,
    itemCount: 17,
    safetyClass: CapabilitySafetyClass.general,
  ),
  InstalledCapability(
    id: 'tax_2026',
    name: 'Tax 2026',
    version: '2.0',
    isFirstParty: true,
    isActive: true,
    itemCount: 52,
    safetyClass: CapabilitySafetyClass.financial,
  ),
  InstalledCapability(
    id: 'audio_scribe',
    name: 'Audio Scribe',
    version: '1.1',
    isFirstParty: true,
    isActive: true,
    itemCount: 4,
    safetyClass: CapabilitySafetyClass.general,
    requiresConsentFor: ['mic'],
  ),
  InstalledCapability(
    id: 'prompt_lab',
    name: 'Prompt Lab',
    version: '1.0',
    isFirstParty: true,
    isActive: true,
    itemCount: 0,
    safetyClass: CapabilitySafetyClass.general,
  ),
];

const List<MindModel> fixtureModels = [
  MindModel(
    id: 'gemma_3n_e4b',
    name: 'Gemma 3n E4B · LiteRT',
    sizeBytes: 1900000000,
    residency: ModelResidency.loaded,
    bench: ModelBench(
      tokensPerSecond: 24.1,
      firstTokenMs: 380,
      residentBytes: 1900000000,
      batteryPercentPerHour: 6,
      measuredUnder: ThermalState.nominal,
      measuredAtMs: fixtureNowMs - 600000,
    ),
  ),
  MindModel(
    id: 'phi_4_mini',
    name: 'Phi-4 mini · 3.8B',
    sizeBytes: 2600000000,
    residency: ModelResidency.available,
  ),
  MindModel(
    id: 'whisper_small',
    name: 'Whisper small · EN/HI',
    sizeBytes: 480000000,
    residency: ModelResidency.resident,
    heldBy: 'Audio Scribe',
  ),
  MindModel(
    id: 'embed_mini',
    name: 'Embed-mini · 384d',
    sizeBytes: 120000000,
    residency: ModelResidency.resident,
    heldBy: 'Vector projection',
  ),
  MindModel(
    id: 'qwen3_4b',
    name: 'Qwen 3 · 4B instruct',
    sizeBytes: 2800000000,
    residency: ModelResidency.available,
  ),
];
```

Add the matching imports at the top of the file:

```dart
import '../models/model_models.dart';
```

- [ ] **Step 4: Implement the five ports**

In `fixture_mind_runtime.dart`, replace the five `throw UnimplementedError()` getters with fields constructed in the constructor, and append the implementations. Add the imports for `projection_models.dart`, `model_models.dart`, `capability_models.dart` and `portability_models.dart`.

```dart
class _FixtureProjections implements ProjectionPort {
  /// The design shows the graph and search rebuilt and embeddings queued for
  /// the same op. Three states, not one summary.
  final Map<ProjectionKind, ProjectionState> _states = {
    ProjectionKind.graph: const ProjectionState(
      kind: ProjectionKind.graph,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 3100,
      opsProcessed: 12481,
      opsTotal: 12481,
    ),
    ProjectionKind.timeline: const ProjectionState(
      kind: ProjectionKind.timeline,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 900,
      opsProcessed: 12481,
      opsTotal: 12481,
    ),
    ProjectionKind.search: const ProjectionState(
      kind: ProjectionKind.search,
      status: ProjectionStatus.queued,
      lastRebuildMs: 3100,
      opsProcessed: 0,
      opsTotal: 12481,
    ),
  };

  @override
  Future<ProjectionState> stateOf(ProjectionKind kind) async => _states[kind]!;

  @override
  Future<List<ProjectionState>> states() async => [
    _states[ProjectionKind.graph]!,
    _states[ProjectionKind.timeline]!,
    _states[ProjectionKind.search]!,
  ];

  @override
  Stream<ProjectionState> rebuild(ProjectionKind kind) async* {
    const total = 12481;
    for (var step = 1; step <= 4; step++) {
      yield ProjectionState(
        kind: kind,
        status: ProjectionStatus.rebuilding,
        lastRebuildMs: 3100,
        opsProcessed: total ~/ 4 * step,
        opsTotal: total,
      );
    }
    final done = ProjectionState(
      kind: kind,
      status: ProjectionStatus.fresh,
      lastRebuildMs: 3100,
      opsProcessed: total,
      opsTotal: total,
    );
    _states[kind] = done;
    yield done;
  }

  @override
  Future<List<SearchHitRef>> search(String query, {String? contextId}) async {
    final needle = query.toLowerCase();
    return fixtureOps
        .where((op) => contextId == null || op.contextId == contextId)
        .where(
          (op) =>
              op.title.toLowerCase().contains(needle) ||
              op.detail.toLowerCase().contains(needle),
        )
        .map(
          (op) => SearchHitRef(
            opSequence: op.sequence,
            title: op.title,
            snippet: op.detail.isEmpty ? op.title : op.detail,
            contextIds: op.contextId.isEmpty ? const [] : [op.contextId],
          ),
        )
        .toList(growable: false);
  }
}

class _FixtureMesh implements MeshPort {
  @override
  Stream<List<MindPeer>> peers() => Stream.value(fixturePeers);

  @override
  Stream<PairingRequest?> pendingRequest() =>
      Stream.value(fixturePairingRequest);

  @override
  Future<void> authorise(PairingRequest request) async {}

  @override
  Future<void> deny(PairingRequest request) async {}

  @override
  Future<int> push(DeviceFingerprint peer) async => 0;
}

class _FixtureCapabilities implements CapabilityPort {
  final Set<String> _removed = {};

  @override
  Future<List<InstalledCapability>> installed() async => fixtureCapabilities
      .where((capability) => !_removed.contains(capability.id))
      .toList(growable: false);

  @override
  Future<InstalledCapability?> byId(String id) async {
    for (final capability in await installed()) {
      if (capability.id == id) return capability;
    }
    return null;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {}

  /// Removes the pack and nothing else. Contexts it created survive — that is
  /// the invariant, and a fixture that quietly dropped them would let a
  /// surface ship claiming otherwise.
  @override
  Future<void> remove(String id) async => _removed.add(id);
}

class _FixtureModels implements ModelPort {
  @override
  Future<List<MindModel>> all() async => fixtureModels;

  @override
  Future<({int usedBytes, int budgetBytes})> storage() async =>
      (usedBytes: 6800000000, budgetBytes: 12000000000);

  @override
  Future<void> load(String modelId) async {}

  @override
  Future<void> unload(String modelId) async {
    final model = fixtureModels.firstWhere((m) => m.id == modelId);
    if (model.residency == ModelResidency.resident) {
      throw StateError(
        'Unloading ${model.name} would break ${model.heldBy}.',
      );
    }
  }

  @override
  Stream<({int received, int total})> download(String modelId) async* {
    final total = fixtureModels.firstWhere((m) => m.id == modelId).sizeBytes;
    for (var step = 1; step <= 5; step++) {
      yield (received: total ~/ 5 * step, total: total);
    }
  }

  @override
  Future<ModelBench> benchmark(String modelId) async {
    final model = fixtureModels.firstWhere((m) => m.id == modelId);
    return model.bench ??
        ModelBench(
          tokensPerSecond: 17,
          firstTokenMs: 900,
          residentBytes: model.sizeBytes,
          batteryPercentPerHour: 9,
          measuredUnder: ThermalState.nominal,
          measuredAtMs: fixtureNowMs,
        );
  }

  @override
  Stream<ThermalState> thermal() => Stream.value(ThermalState.nominal);
}

class _FixturePortability implements PortabilityPort {
  /// Per-context bytes, split the way the design's bar splits them.
  static const _perContext = {
    'kneesurgery2026': [
      ContentClassSize('Scans', 620000000),
      ContentClassSize('Audio', 410000000),
      ContentClassSize('Log', 180000000),
    ],
    'downtownapartment': [
      ContentClassSize('Scans', 240000000),
      ContentClassSize('Audio', 190000000),
      ContentClassSize('Log', 90000000),
    ],
    'q3taxfiling': [
      ContentClassSize('Scans', 340000000),
      ContentClassSize('Audio', 180000000),
      ContentClassSize('Log', 120000000),
    ],
    'airoarchitecture': [
      ContentClassSize('Scans', 0),
      ContentClassSize('Audio', 0),
      ContentClassSize('Log', 30000000),
    ],
  };

  @override
  Future<RecoveryPackagePlan> plan(List<String> contextIds) async {
    var scans = 0;
    var audio = 0;
    var log = 0;
    for (final id in contextIds) {
      final bands = _perContext[id];
      if (bands == null) continue;
      scans += bands[0].bytes;
      audio += bands[1].bytes;
      log += bands[2].bytes;
    }
    return RecoveryPackagePlan(
      selectedContextIds: List.unmodifiable(contextIds),
      breakdown: [
        ContentClassSize('Scans', scans),
        ContentClassSize('Audio', audio),
        ContentClassSize('Log', log),
      ],
      fileName: 'airo-2026-08-01.airobackup',
    );
  }

  @override
  Stream<({int written, int total})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  }) async* {
    final total = plan.totalBytes;
    for (var step = 1; step <= 5; step++) {
      yield (written: total ~/ 5 * step, total: total);
    }
  }
}
```

Wire them into the class:

```dart
  FixtureMindRuntime()
    : _log = _FixtureLog(),
      _contexts = _FixtureContexts(),
      _vault = const _FixtureVault(),
      _projections = _FixtureProjections(),
      _mesh = _FixtureMesh(),
      _capabilities = _FixtureCapabilities(),
      _models = _FixtureModels(),
      _portability = _FixturePortability();

  final _FixtureProjections _projections;
  final _FixtureMesh _mesh;
  final _FixtureCapabilities _capabilities;
  final _FixtureModels _models;
  final _FixturePortability _portability;

  @override
  ProjectionPort get projections => _projections;

  @override
  MeshPort get mesh => _mesh;

  @override
  CapabilityPort get capabilities => _capabilities;

  @override
  ModelPort get models => _models;

  @override
  PortabilityPort get portability => _portability;
```

- [ ] **Step 5: Run both fixture test files**

Run: `cd packages/feature_mind && flutter test test/runtime/`

Expected: PASS, 19 tests across three files.

- [ ] **Step 6: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): fixture projections, mesh, capabilities, models, portability

Rebuild and download emit partial progress rather than resolving
instantly, so no surface can ship having never rendered its own loading
state. Removing a capability leaves its contexts alone — the fixture
holds that invariant so a screen cannot claim otherwise.

Refs #1449"
```

---

### Task 6: `RustMindRuntime`, partial

The real implementation, honest about what it cannot do yet. Every method throws `MindPortUnavailable` naming its port and the milestone 19 issue that will fill it in. As those issues land, methods are replaced one at a time and no surface changes.

This is the only file in the module permitted to import the generated bridge.

**Files:**
- Create: `packages/feature_mind/lib/src/runtime/rust/rust_mind_runtime.dart`
- Test: `packages/feature_mind/test/runtime/rust_mind_runtime_test.dart`

**Interfaces:**
- Consumes: the ports from Task 3.
- Produces: `RustMindRuntime()`. Task 12's harness asserts both implementations satisfy the same port surface.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/runtime/rust_mind_runtime_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RustMindRuntime runtime;

  setUp(() => runtime = RustMindRuntime());

  test('every unimplemented method names its port and its issue', () async {
    await expectLater(
      runtime.mesh.push(const DeviceFingerprint('A', 'B', 'C')),
      throwsA(
        isA<MindPortUnavailable>()
            .having((e) => e.port, 'port', 'MeshPort')
            .having((e) => e.reason, 'reason', contains('#')),
      ),
    );
  });

  test('the failure is per port, not per product', () async {
    // A surface that only needs the log must be able to tell that the log is
    // the thing missing, not conclude the whole runtime is dead.
    await expectLater(
      runtime.log.count(),
      throwsA(
        isA<MindPortUnavailable>().having((e) => e.port, 'port', 'OperationLogPort'),
      ),
    );
    await expectLater(
      runtime.vault.state(),
      throwsA(
        isA<MindPortUnavailable>().having((e) => e.port, 'port', 'VaultPort'),
      ),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/runtime/rust_mind_runtime_test.dart`

Expected: FAIL — "Undefined name 'RustMindRuntime'".

- [ ] **Step 3: Write the implementation**

Create `packages/feature_mind/lib/src/runtime/rust/rust_mind_runtime.dart`. The pattern below is shown in full for `VaultPort`, `OperationLogPort` and `MeshPort`; repeat it verbatim for the other five ports, changing only the port name and the issue reference.

```dart
import '../mind_runtime.dart';
import '../models/context_models.dart';
import '../models/log_models.dart';
import '../models/mesh_models.dart';
import '../models/model_models.dart';
import '../models/portability_models.dart';
import '../models/projection_models.dart';
import '../models/vault_models.dart';
import '../models/capability_models.dart';
import '../ports/capability_port.dart';
import '../ports/context_port.dart';
import '../ports/mesh_port.dart';
import '../ports/model_port.dart';
import '../ports/operation_log_port.dart';
import '../ports/portability_port.dart';
import '../ports/projection_port.dart';
import '../ports/vault_port.dart';

/// The real runtime, honest about what milestone 19 has not landed.
///
/// Every method here either delegates to `rust/airo_mind_runtime` or throws
/// [MindPortUnavailable] naming its port and the issue that fills it in. As
/// those issues land, methods are replaced one at a time and no surface
/// changes — that is what the port bought.
///
/// This is the only file in the module allowed to import the generated bridge.
class RustMindRuntime implements MindRuntime {
  RustMindRuntime();

  @override
  final VaultPort vault = const _RustVault();

  @override
  final OperationLogPort log = const _RustLog();

  @override
  final ContextPort contexts = const _RustContexts();

  @override
  final ProjectionPort projections = const _RustProjections();

  @override
  final MeshPort mesh = const _RustMesh();

  @override
  final CapabilityPort capabilities = const _RustCapabilities();

  @override
  final ModelPort models = const _RustModels();

  @override
  final PortabilityPort portability = const _RustPortability();
}

Never _pending(String port, String issue) =>
    throw MindPortUnavailable(port, 'not implemented yet — $issue');

class _RustVault implements VaultPort {
  const _RustVault();

  static const _issue = '#1207, #1208, #1210';

  @override
  Future<VaultState> state() async => _pending('VaultPort', _issue);

  @override
  Future<List<MindDevice>> devices() async => _pending('VaultPort', _issue);

  @override
  Future<void> revokeDevice(DeviceFingerprint fingerprint) async =>
      _pending('VaultPort', _issue);
}

class _RustLog implements OperationLogPort {
  const _RustLog();

  static const _issue = '#1213, #1214, #1215';

  @override
  Future<int> count() async => _pending('OperationLogPort', _issue);

  @override
  Future<List<MindOp>> range({required int offset, required int limit}) async =>
      _pending('OperationLogPort', _issue);

  @override
  Future<MindOp?> bySequence(int sequence) async =>
      _pending('OperationLogPort', _issue);

  @override
  Future<int> append({
    required MindOpKind kind,
    required String title,
    required String contextId,
    String detail = '',
  }) async => _pending('OperationLogPort', _issue);

  @override
  Future<SignatureState> verify(int sequence) async =>
      _pending('OperationLogPort', _issue);

  @override
  Stream<double> replayFrom(int sequence) =>
      Stream.error(const MindPortUnavailable(
        'OperationLogPort',
        'not implemented yet — #1216',
      ));
}

class _RustMesh implements MeshPort {
  const _RustMesh();

  static const _issue = '#1200';

  @override
  Stream<List<MindPeer>> peers() =>
      Stream.error(const MindPortUnavailable('MeshPort', 'not implemented yet — $_issue'));

  @override
  Stream<PairingRequest?> pendingRequest() =>
      Stream.error(const MindPortUnavailable('MeshPort', 'not implemented yet — $_issue'));

  @override
  Future<void> authorise(PairingRequest request) async =>
      _pending('MeshPort', _issue);

  @override
  Future<void> deny(PairingRequest request) async => _pending('MeshPort', _issue);

  @override
  Future<int> push(DeviceFingerprint peer) async => _pending('MeshPort', _issue);
}
```

Repeat the same shape for `_RustContexts` (issues `#1228, #1229`), `_RustProjections` (`#1218, #1219, #1220`), `_RustCapabilities` (`#1222`), `_RustModels` (`#1260`) and `_RustPortability` (`#1211, #1305`).

- [ ] **Step 4: Export and run the test**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/runtime/rust/rust_mind_runtime.dart';
```

Run: `cd packages/feature_mind && flutter test test/runtime/rust_mind_runtime_test.dart`

Expected: PASS, 2 tests.

- [ ] **Step 5: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): RustMindRuntime, partial and honest about it

Every method throws MindPortUnavailable naming its port and the M19
issue that fills it in. Methods get replaced one at a time as those land
and no surface changes — that is what the port bought.

Refs #1449"
```

---

### Task 7: `MindPresencePip` and `MindNumberStrip` — rules R01 and R04

Two status-readout widgets that carry two rules. Grouped because they are tested the same way and a reviewer would accept or reject them together.

R01: a teal pip on every screen; teal means the work happened on this device. R04: ops, peers and vault state stay visible.

**Files:**
- Create: `packages/feature_mind/lib/src/widgets/mind_presence_pip.dart`
- Create: `packages/feature_mind/lib/src/widgets/mind_number_strip.dart`
- Test: `packages/feature_mind/test/widgets/presence_and_numbers_test.dart`

**Interfaces:**
- Consumes: `VaultState`, `MindPeer` from Task 2.
- Produces: `MindPresencePip({required bool isLocal, String? remoteLabel})` and `MindNumberStrip({required int opCount, required int peerCount, required bool vaultSealed})`. Task 12's harness looks for these two types by `find.byType`.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/widgets/presence_and_numbers_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('R01 presence', () {
    testWidgets('local work is teal and says so', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: MindPresencePip(isLocal: true))),
      );

      expect(find.text('ON-DEVICE'), findsOneWidget);
      final pip = tester.widget<Container>(
        find.byKey(const Key('mind.presence.dot')),
      );
      expect(
        (pip.decoration! as BoxDecoration).color,
        MindPresencePip.localColour,
      );
    });

    testWidgets('remote work is not teal and names where it ran',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindPresencePip(isLocal: false, remoteLabel: 'iPad Air'),
          ),
        ),
      );

      expect(find.text('iPad Air'), findsOneWidget);
      final pip = tester.widget<Container>(
        find.byKey(const Key('mind.presence.dot')),
      );
      expect(
        (pip.decoration! as BoxDecoration).color,
        isNot(MindPresencePip.localColour),
      );
    });
  });

  group('R04 numbers', () {
    testWidgets('shows ops, peers and vault state as numbers', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindNumberStrip(
              opCount: 12481,
              peerCount: 3,
              vaultSealed: true,
            ),
          ),
        ),
      );

      expect(find.text('12,481 ops'), findsOneWidget);
      expect(find.text('3 on LAN'), findsOneWidget);
      expect(find.text('Sealed'), findsOneWidget);
    });

    testWidgets('zero peers is a number, not an empty slot', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MindNumberStrip(
              opCount: 0,
              peerCount: 0,
              vaultSealed: false,
            ),
          ),
        ),
      );

      expect(find.text('0 ops'), findsOneWidget);
      expect(find.text('0 on LAN'), findsOneWidget);
      expect(find.text('Unsealed'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/widgets/presence_and_numbers_test.dart`

Expected: FAIL — "Undefined name 'MindPresencePip'".

- [ ] **Step 3: Write the presence pip**

Create `packages/feature_mind/lib/src/widgets/mind_presence_pip.dart`:

```dart
import 'package:flutter/material.dart';

/// Rule R01. A pip on every Mind screen saying where the work ran.
///
/// Teal means this device. Anything else means it ran somewhere the person
/// also owns, and the label says which — a pip that only ever showed one
/// state would be decoration, and the rule exists because locality is the
/// product's central claim.
class MindPresencePip extends StatelessWidget {
  const MindPresencePip({super.key, required this.isLocal, this.remoteLabel});

  final bool isLocal;

  /// Which device did the work. Required in practice when [isLocal] is false;
  /// falls back to a truthful "ELSEWHERE" rather than implying locality.
  final String? remoteLabel;

  static const Color localColour = Color(0xFF7FE8DE);
  static const Color remoteColour = Color(0xFFFFFF89);

  @override
  Widget build(BuildContext context) {
    final colour = isLocal ? localColour : remoteColour;
    final label = isLocal ? 'ON-DEVICE' : (remoteLabel ?? 'ELSEWHERE');

    return Semantics(
      label: isLocal
          ? 'Work ran on this device'
          : 'Work ran on $label',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const Key('mind.presence.dot'),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: colour),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colour,
              fontSize: 10,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Write the number strip**

Create `packages/feature_mind/lib/src/widgets/mind_number_strip.dart`:

```dart
import 'package:flutter/material.dart';

/// Rule R04. Ops, peers and vault state, always visible.
///
/// Every cell renders a value even at zero. "0 on LAN" tells a person the
/// mesh is working and alone; an empty slot tells them the app is broken.
class MindNumberStrip extends StatelessWidget {
  const MindNumberStrip({
    super.key,
    required this.opCount,
    required this.peerCount,
    required this.vaultSealed,
  });

  final int opCount;
  final int peerCount;
  final bool vaultSealed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Cell(label: 'LOG', value: '${_grouped(opCount)} ops'),
        _Cell(label: 'PEERS', value: '$peerCount on LAN'),
        _Cell(label: 'VAULT', value: vaultSealed ? 'Sealed' : 'Unsealed'),
      ],
    );
  }

  /// Thousands separators. 12481 is a number a person has to parse; 12,481 is
  /// one they can read at a glance, and this strip is read at a glance.
  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 9, letterSpacing: 1.6),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Export and run the test**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/widgets/mind_number_strip.dart';
export 'src/widgets/mind_presence_pip.dart';
```

Run: `cd packages/feature_mind && flutter test test/widgets/presence_and_numbers_test.dart`

Expected: PASS, 4 tests.

- [ ] **Step 6: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): presence pip and number strip — rules R01 and R04

Zero renders as '0 on LAN', not as an empty slot: a number tells a person
the mesh works and is alone, an empty slot tells them the app is broken.

Refs #1449"
```

---

### Task 8: `MindContextChip` — rule R02

Tags are tappable everywhere, never decorative. That means two enforced properties: a tap target of at least 48 logical pixels, and a callback that actually goes somewhere.

The 48 px floor is not a style preference — it is the phone surface's stated minimum target, and a chip that renders at 24 px high is a chip a person misses.

**Files:**
- Create: `packages/feature_mind/lib/src/widgets/mind_context_chip.dart`
- Test: `packages/feature_mind/test/widgets/context_chip_test.dart`

**Interfaces:**
- Consumes: `MindContext` from Task 2.
- Produces: `MindContextChip({required MindContext context, required VoidCallback onTap, bool isSelected})` and `MindContextChip.minimumTarget` (`48.0`).

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/widgets/context_chip_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = MindContext(
  id: 'kneesurgery2026',
  label: '#KneeSurgery2026',
  itemCount: 38,
  opCount: 1204,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.health,
);

void main() {
  testWidgets('R02 — a chip renders its label and its count', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    expect(find.text('#KneeSurgery2026'), findsOneWidget);
    expect(find.text('38'), findsOneWidget);
  });

  testWidgets('R02 — a chip is at least 48 logical pixels tall',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    final size = tester.getSize(find.byType(MindContextChip));
    expect(size.height, greaterThanOrEqualTo(MindContextChip.minimumTarget));
  });

  testWidgets('R02 — tapping a chip calls through', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(MindContextChip));
    expect(taps, 1);
  });

  testWidgets('R02 — a chip carries a semantic label naming its context',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindContextChip(context: _context, onTap: () {}),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(MindContextChip)).label,
      contains('#KneeSurgery2026'),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/widgets/context_chip_test.dart`

Expected: FAIL — "Undefined name 'MindContextChip'".

- [ ] **Step 3: Write the widget**

Create `packages/feature_mind/lib/src/widgets/mind_context_chip.dart`:

```dart
import 'package:flutter/material.dart';

import '../runtime/models/context_models.dart';

/// Rule R02. A hypergraph tag, everywhere it appears, always tappable.
///
/// [onTap] is required rather than nullable. A decorative tag is the failure
/// this rule exists to prevent, and an optional callback is how decorative
/// tags get written.
class MindContextChip extends StatelessWidget {
  const MindContextChip({
    super.key,
    required this.context,
    required this.onTap,
    this.isSelected = false,
  });

  final MindContext context;
  final VoidCallback onTap;
  final bool isSelected;

  /// The phone surface's stated floor. A 24 px chip is one a person misses.
  static const double minimumTarget = 48;

  @override
  Widget build(BuildContext buildContext) {
    final colour = isSelected
        ? const Color(0xFF7FE8DE)
        : const Color(0x4DFFE6CB);

    return Semantics(
      button: true,
      label: '${context.label}, ${context.itemCount} items',
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minimumTarget),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: colour)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSelected
                        ? const Color(0xFF7FE8DE)
                        : const Color(0xFFFFE6CB),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.itemCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x99FFE6CB),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Export and run the test**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/widgets/mind_context_chip.dart';
```

Run: `cd packages/feature_mind && flutter test test/widgets/context_chip_test.dart`

Expected: PASS, 4 tests.

- [ ] **Step 5: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): context chip — rule R02

onTap is required, not nullable. A decorative tag is the failure this
rule exists to prevent, and an optional callback is how decorative tags
get written.

Refs #1449"
```

---

### Task 9: `MindProjectionSwitcher` and the route gate — rule R03

Graph, Timeline and Search are one switcher, never three destinations. A widget alone cannot enforce that: someone can always add `GoRoute(path: '/mind/graph')` and split them. So this task ships both the widget and a repo-wide shell check, matching the existing `scripts/check-*.sh` policy-gate pattern.

**Files:**
- Create: `packages/feature_mind/lib/src/widgets/mind_projection_switcher.dart`
- Create: `scripts/check-mind-projection-routes.sh`
- Test: `packages/feature_mind/test/widgets/projection_switcher_test.dart`

**Interfaces:**
- Consumes: `ProjectionKind` from Task 2.
- Produces: `MindProjectionSwitcher({required ProjectionKind selected, required ValueChanged<ProjectionKind> onChanged})`; the script `scripts/check-mind-projection-routes.sh` exiting non-zero on a violation.

- [ ] **Step 1: Write the failing widget test**

Create `packages/feature_mind/test/widgets/projection_switcher_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R03 — all three projections are on one control',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.graph,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('GRAPH'), findsOneWidget);
    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('SEARCH'), findsOneWidget);
  });

  testWidgets('R03 — selecting a projection reports which, not a route',
      (tester) async {
    ProjectionKind? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.graph,
            onChanged: (kind) => chosen = kind,
          ),
        ),
      ),
    );

    await tester.tap(find.text('SEARCH'));
    expect(chosen, ProjectionKind.search);
  });

  testWidgets('R03 — every segment meets the 48px target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindProjectionSwitcher(
            selected: ProjectionKind.timeline,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(MindProjectionSwitcher)).height,
      greaterThanOrEqualTo(48),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/widgets/projection_switcher_test.dart`

Expected: FAIL — "Undefined name 'MindProjectionSwitcher'".

- [ ] **Step 3: Write the widget**

Create `packages/feature_mind/lib/src/widgets/mind_projection_switcher.dart`:

```dart
import 'package:flutter/material.dart';

import '../runtime/models/projection_models.dart';

/// Rule R03. One control for three views of one log.
///
/// Graph, timeline and search are projections, not places. Routing to them
/// separately would teach a person they are three features that happen to
/// share data, which is the opposite of what the runtime is.
///
/// `scripts/check-mind-projection-routes.sh` enforces the other half: no route
/// may target a single projection.
class MindProjectionSwitcher extends StatelessWidget {
  const MindProjectionSwitcher({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final ProjectionKind selected;
  final ValueChanged<ProjectionKind> onChanged;

  static const _labels = {
    ProjectionKind.graph: 'GRAPH',
    ProjectionKind.timeline: 'TIMELINE',
    ProjectionKind.search: 'SEARCH',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final kind in ProjectionKind.values)
          Expanded(
            child: InkWell(
              onTap: () => onChanged(kind),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                color: kind == selected
                    ? const Color(0xFFFFE6CB)
                    : Colors.transparent,
                child: Text(
                  _labels[kind]!,
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: kind == selected
                        ? const Color(0xFF041C1C)
                        : const Color(0x99FFE6CB),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Write the route gate**

Create `scripts/check-mind-projection-routes.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Rule R03: graph, timeline and search are one switcher, never three
# destinations. A widget cannot enforce that on its own -- someone can always
# add a GoRoute for one of them -- so this gate checks the routes.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

scan_paths=()
for path in "app/lib" "packages"; do
  [[ -e "$path" ]] && scan_paths+=("$path")
done

if [[ ${#scan_paths[@]} -eq 0 ]]; then
  echo "No Dart sources to scan."
  exit 0
fi

violations="$(
  rg -n \
    --glob '*.dart' \
    --glob '!**/test/**' \
    -e "path:\s*'/?(mind/)?(graph|timeline|search)'" \
    -e "name:\s*'mind_(graph|timeline|search)'" \
    "${scan_paths[@]}" || true
)"

if [[ -n "$violations" ]]; then
  cat >&2 <<'EOF'
Rule R03 violation: a route targets a single projection.

Graph, timeline and search are three views of one log, reached through
MindProjectionSwitcher on one screen. Routing to them separately teaches a
person they are three features that share data, which is the opposite of what
the runtime is.

EOF
  echo "$violations" >&2
  exit 1
fi

echo "R03 OK: no route targets a single projection."
```

Make it executable:

```bash
chmod +x scripts/check-mind-projection-routes.sh
```

- [ ] **Step 5: Prove the gate can fail**

A gate that has never failed proves nothing. Add its mutation test as a shell assertion in the same file's test — create `packages/feature_mind/test/rules/r03_route_gate_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The mutation test for R03's route gate.
///
/// Writes a file that violates the rule, runs the gate, asserts it fails, then
/// removes the file. Without this, a gate with a broken regex passes forever
/// and reads as enforcement.
void main() {
  test('the R03 gate fails on a route that targets one projection', () {
    final root = Directory.current.parent.parent;
    final offender = File(
      '${root.path}/app/lib/r03_mutation_probe.dart',
    );

    offender.writeAsStringSync('''
// Temporary probe written by r03_route_gate_test.dart.
const route = GoRoute(path: '/mind/graph', name: 'mind_graph');
''');

    try {
      final result = Process.runSync(
        '${root.path}/scripts/check-mind-projection-routes.sh',
        const [],
      );
      expect(
        result.exitCode,
        isNonZero,
        reason: 'The gate passed a route that targets a single projection. '
            'Its pattern is broken and it is enforcing nothing.',
      );
    } finally {
      if (offender.existsSync()) offender.deleteSync();
    }
  });

  test('the R03 gate passes a clean tree', () {
    final root = Directory.current.parent.parent;
    final result = Process.runSync(
      '${root.path}/scripts/check-mind-projection-routes.sh',
      const [],
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });
}
```

- [ ] **Step 6: Export and run everything**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/widgets/mind_projection_switcher.dart';
```

Run:

```bash
cd packages/feature_mind && flutter test test/widgets/projection_switcher_test.dart test/rules/r03_route_gate_test.dart
```

Expected: PASS, 5 tests.

- [ ] **Step 7: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind scripts/check-mind-projection-routes.sh
git commit -m "feat(mind): projection switcher and route gate — rule R03

The widget puts three projections on one control; the gate stops anyone
adding a fourth destination behind its back. The gate carries a mutation
test, because a gate that has never failed proves nothing.

Refs #1449"
```

---

### Task 10: `MindOpRow`

The provenance row. It appears in the timeline, the console table, the search results and the inspector, and it is how a person answers "where did this come from".

Signature state is rendered, not assumed. An op whose signature does not verify must look different from one that does — that difference is the only reason the column exists.

**Files:**
- Create: `packages/feature_mind/lib/src/widgets/mind_op_row.dart`
- Test: `packages/feature_mind/test/widgets/op_row_test.dart`

**Interfaces:**
- Consumes: `MindOp`, `SignatureState` from Task 2.
- Produces: `MindOpRow({required MindOp op, VoidCallback? onTap})`.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/widgets/op_row_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _verified = MindOp(
  sequence: 12388,
  kind: MindOpKind.scan,
  title: 'Invoice · Kitchen repair, Basu Contracting',
  contextId: 'q3taxfiling',
  deviceName: 'Pixel 9 Pro',
  signature: SignatureState.verified,
  recordedAtMs: 0,
);

void main() {
  testWidgets('shows the op number, because that is what gets cited',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MindOpRow(op: _verified))),
    );

    expect(find.text('op 12,388'), findsOneWidget);
    expect(find.text('Invoice · Kitchen repair, Basu Contracting'),
        findsOneWidget);
  });

  testWidgets('attributes the op to the device that wrote it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MindOpRow(op: _verified))),
    );

    expect(find.text('Pixel 9 Pro'), findsOneWidget);
  });

  testWidgets('an unverified signature looks different from a verified one',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const MindOpRow(op: _verified),
              MindOpRow(
                op: _verified.copyWith(signature: SignatureState.unverified),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('verified'), findsOneWidget);
    expect(find.text('UNVERIFIED'), findsOneWidget);

    final badges = tester
        .widgetList<Text>(find.byKey(const Key('mind.op.signature')))
        .toList();
    expect(badges.first.style?.color, isNot(badges.last.style?.color));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/widgets/op_row_test.dart`

Expected: FAIL — "Undefined name 'MindOpRow'".

- [ ] **Step 3: Write the widget**

Create `packages/feature_mind/lib/src/widgets/mind_op_row.dart`:

```dart
import 'package:flutter/material.dart';

import '../runtime/models/log_models.dart';
import 'mind_number_strip.dart' show MindNumberStrip;

/// One row of the log, wherever the log is shown.
///
/// Carries the op number because that is what everything else cites: the
/// agent's grounded answers, the inspector, a person asking where a claim came
/// from. A row without its number breaks that chain.
class MindOpRow extends StatelessWidget {
  const MindOpRow({super.key, required this.op, this.onTap});

  final MindOp op;
  final VoidCallback? onTap;

  static const _signatureLabels = {
    SignatureState.verified: 'verified',
    SignatureState.unverified: 'UNVERIFIED',
    SignatureState.unsigned: 'UNSIGNED',
  };

  /// Unverified is loud on purpose. It is the one state a person must not
  /// scroll past.
  static const _signatureColours = {
    SignatureState.verified: Color(0x99FFE6CB),
    SignatureState.unverified: Color(0xFFFF6B6B),
    SignatureState.unsigned: Color(0xFFFFFF89),
  };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    op.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        op.deviceName,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0x8CFFE6CB),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _signatureLabels[op.signature]!,
                        key: const Key('mind.op.signature'),
                        style: TextStyle(
                          fontSize: 11,
                          color: _signatureColours[op.signature],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'op ${_grouped(op.sequence)}',
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 1,
                color: Color(0x73FFE6CB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _grouped(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
```

Note: the `import ... show MindNumberStrip` line above is unused — remove it. Number grouping is duplicated here deliberately rather than exported from `MindNumberStrip`, whose copy is private; if a third caller appears, extract it to `lib/src/widgets/_grouped_number.dart` then.

- [ ] **Step 4: Export and run the test**

Add to `packages/feature_mind/lib/feature_mind.dart`:

```dart
export 'src/widgets/mind_op_row.dart';
```

Run: `cd packages/feature_mind && flutter test test/widgets/op_row_test.dart`

Expected: PASS, 3 tests.

- [ ] **Step 5: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): op provenance row

Carries the op number, because everything else cites it — grounded
answers, the inspector, a person asking where a claim came from. An
unverified signature renders loud; it is the one state a person must not
scroll past.

Refs #1449"
```

---

### Task 11: `feature_mind_absent` and the private-device gate — rule R05

Mind renders only on a device one person owns. Web and TV are shared surfaces, so Mind is absent from those binaries rather than disabled inside them.

Link-time, not runtime. A runtime flag can be flipped; an absent package cannot be reached.

This task builds the swap package and the gate. Wiring the swap into `pubspec_tv.yaml` and the web build is [#1465](https://github.com/DevelopersCoffee/airo/issues/1465) — the gate here passes today because no shared flavor links `feature_mind` yet, and the mutation test proves the gate can still fail.

**Files:**
- Create: `packages/feature_mind_absent/pubspec.yaml`
- Create: `packages/feature_mind_absent/module.yaml`
- Create: `packages/feature_mind_absent/lib/feature_mind.dart`
- Create: `packages/feature_mind_absent/analysis_options.yaml`
- Create: `scripts/check-mind-private-devices.sh`
- Test: `packages/feature_mind/test/rules/r05_private_devices_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: a package named `feature_mind` (in `packages/feature_mind_absent/`) exposing `AiroMindAbsent`; `scripts/check-mind-private-devices.sh`.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/rules/r05_private_devices_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R05: Mind renders only on a device one person owns.
///
/// The gate asserts no shared-surface flavor links feature_mind. The mutation
/// test asserts the gate can fail — a check that has never failed is not
/// enforcement, it is decoration that survives review by being green.
void main() {
  late Directory root;

  setUp(() => root = Directory.current.parent.parent);

  test('the R05 gate passes the current tree', () {
    final result = Process.runSync(
      '${root.path}/scripts/check-mind-private-devices.sh',
      const [],
    );

    expect(result.exitCode, 0, reason: result.stderr.toString());
  });

  test('the R05 gate fails when a shared flavor links feature_mind', () {
    final tv = File('${root.path}/app/pubspec_tv.yaml');
    final original = tv.readAsStringSync();

    tv.writeAsStringSync('$original\n  feature_mind:\n    path: ../packages/feature_mind\n');

    try {
      final result = Process.runSync(
        '${root.path}/scripts/check-mind-private-devices.sh',
        const [],
      );
      expect(
        result.exitCode,
        isNonZero,
        reason: 'The gate let the TV flavor link feature_mind. A shared '
            'screen must not be able to render a personal vault.',
      );
    } finally {
      tv.writeAsStringSync(original);
    }
  });

  test('the absent swap declares the same package name', () {
    final swap = File(
      '${root.path}/packages/feature_mind_absent/pubspec.yaml',
    ).readAsStringSync();

    // The override only works if the swap answers to the same name.
    expect(swap, contains('name: feature_mind'));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/rules/r05_private_devices_test.dart`

Expected: FAIL — the script does not exist.

- [ ] **Step 3: Write the swap package**

Create `packages/feature_mind_absent/pubspec.yaml`:

```yaml
# Deliberately named feature_mind. This package exists to be swapped in via
# pubspec_overrides.yaml on shared-surface flavors -- web and TV -- so that the
# Mind module is absent from those binaries rather than disabled inside them.
#
# Rule R05. A personal vault must not render on a screen other people use, and
# a runtime flag can be flipped. Same mechanism as packages/airo_pro_bootstrap.
name: feature_mind
description: "No-op Airo Mind. Swapped in on shared surfaces where Mind must not exist."
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.12.2
  flutter: ">=3.0.0"

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

Create `packages/feature_mind_absent/lib/feature_mind.dart`:

```dart
/// Airo Mind, absent.
///
/// Every name the real package exports is either missing here or inert. That
/// is the point: a shared-surface build should fail to compile if it reaches
/// for a Mind surface, rather than compiling and showing an empty screen.
///
/// The one name that does exist is [AiroMindAbsent], which the product shell
/// checks to decide whether to offer a Mind destination at all.
library;

/// Marks this build as one where Mind does not exist.
///
/// `const AiroMindAbsent.value` is `true` here and absent from the real
/// package, so a shell that reads it gets a compile error rather than a
/// silently wrong answer if the two ever drift.
class AiroMindAbsent {
  const AiroMindAbsent._();

  static const bool value = true;
}
```

Create `packages/feature_mind_absent/module.yaml`:

```yaml
name: feature_mind_absent
owner: Chief Security Officer
reviewers:
  - Chief Architect
  - Chief Release DevOps Officer
allowed_dependencies: []
forbidden_dependencies:
  - app
  - feature_mind
quality_gates: {}
```

Create `packages/feature_mind_absent/analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml
```

- [ ] **Step 4: Write the gate**

Create `scripts/check-mind-private-devices.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Rule R05: Airo Mind renders only on a device one person owns.
#
# Web and TV are shared surfaces. Mind is absent from those binaries, not
# disabled inside them -- a runtime flag can be flipped, an absent package
# cannot be reached. This gate asserts the shared-surface flavors do not link
# the real feature_mind.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Pubspecs whose builds reach a screen other people can see.
shared_pubspecs=("app/pubspec_tv.yaml")

failed=false

for pubspec in "${shared_pubspecs[@]}"; do
  [[ -f "$pubspec" ]] || continue

  # A dependency on feature_mind is only acceptable when the same flavor
  # overrides it with the absent swap.
  if grep -qE '^\s+feature_mind:' "$pubspec"; then
    overrides="${pubspec%.yaml}_overrides.yaml"
    if ! grep -qE 'feature_mind_absent' "$pubspec" \
       && ! { [[ -f "$overrides" ]] && grep -qE 'feature_mind_absent' "$overrides"; }; then
      failed=true
      echo "R05 violation: $pubspec links feature_mind with no absent swap." >&2
    fi
  fi
done

# The web build uses app/pubspec.yaml. Mind may be a dependency there for the
# phone and desktop targets, so the check is on the web entrypoint instead:
# nothing under app/web or a web-only entrypoint may import it.
if [[ -d "app/web" ]]; then
  web_imports="$(
    rg -n --glob '*.dart' -e "package:feature_mind/" app/web 2>/dev/null || true
  )"
  if [[ -n "$web_imports" ]]; then
    failed=true
    echo "R05 violation: web sources import feature_mind." >&2
    echo "$web_imports" >&2
  fi
fi

if [[ "$failed" == true ]]; then
  cat >&2 <<'EOF'

A personal vault must not render on a screen other people use. Swap in
packages/feature_mind_absent through pubspec_overrides.yaml rather than
hiding the module at runtime.
EOF
  exit 1
fi

echo "R05 OK: no shared-surface flavor links feature_mind."
```

Make it executable:

```bash
chmod +x scripts/check-mind-private-devices.sh
```

- [ ] **Step 5: Run the test**

Run: `cd packages/feature_mind && flutter test test/rules/r05_private_devices_test.dart`

Expected: PASS, 3 tests. If the mutation test fails, the gate's grep is wrong — fix the gate, not the test.

- [ ] **Step 6: Analyze, format, commit**

```bash
cd packages/feature_mind_absent && flutter analyze --fatal-infos
cd ../feature_mind && flutter analyze --fatal-infos
cd ../.. && dart format --set-exit-if-changed packages/feature_mind packages/feature_mind_absent
git add packages/feature_mind packages/feature_mind_absent scripts/check-mind-private-devices.sh
git commit -m "feat(mind): absent swap package and the R05 private-device gate

Web and TV are shared surfaces. Mind is absent from those binaries, not
disabled inside them: a runtime flag can be flipped, an absent package
cannot be reached. The gate carries a mutation test that adds the
dependency to pubspec_tv.yaml and asserts the gate rejects it.

Refs #1449, #1465"
```

---

### Task 12: The rule harness

One assertion a surface author calls, that checks R01–R04 in a single line. Without it, every surface in P1–P3 reimplements four checks and drifts.

R05 is not in the harness — it is a repo gate, not a per-surface property.

**Files:**
- Create: `packages/feature_mind/lib/src/testing/mind_rule_harness.dart`
- Create: `packages/feature_mind/lib/testing.dart`
- Test: `packages/feature_mind/test/rules/harness_test.dart`

**Interfaces:**
- Consumes: the five widgets from Tasks 7–10.
- Produces: `expectSatisfiesMindRules(WidgetTester tester, {bool expectsNumbers})`, exported from `package:feature_mind/testing.dart`. Every P1–P3 surface test calls it.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/rules/harness_test.dart`:

```dart
import 'package:feature_mind/feature_mind.dart';
import 'package:feature_mind/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _context = MindContext(
  id: 'kneesurgery2026',
  label: '#KneeSurgery2026',
  itemCount: 38,
  opCount: 1204,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.health,
);

/// A surface that obeys the rules.
class _CompliantSurface extends StatelessWidget {
  const _CompliantSurface();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const MindPresencePip(isLocal: true),
        const MindNumberStrip(opCount: 12481, peerCount: 3, vaultSealed: true),
        MindContextChip(context: _context, onTap: () {}),
      ],
    ),
  );
}

/// A surface missing its presence pip.
class _NoPipSurface extends StatelessWidget {
  const _NoPipSurface();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        const MindNumberStrip(opCount: 1, peerCount: 0, vaultSealed: true),
        MindContextChip(context: _context, onTap: () {}),
      ],
    ),
  );
}

void main() {
  testWidgets('the harness passes a compliant surface', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _CompliantSurface()));

    await expectSatisfiesMindRules(tester);
  });

  testWidgets('the harness fails a surface with no presence pip',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _NoPipSurface()));

    // The mutation test for R01: if this passes, the harness enforces nothing.
    await expectLater(
      () => expectSatisfiesMindRules(tester),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('the harness fails a surface with no numbers when it claims them',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MindPresencePip(isLocal: true)),
      ),
    );

    await expectLater(
      () => expectSatisfiesMindRules(tester, expectsNumbers: true),
      throwsA(isA<TestFailure>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/rules/harness_test.dart`

Expected: FAIL — "Target of URI doesn't exist: 'package:feature_mind/testing.dart'".

- [ ] **Step 3: Write the harness**

Create `packages/feature_mind/lib/src/testing/mind_rule_harness.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/mind_context_chip.dart';
import '../widgets/mind_number_strip.dart';
import '../widgets/mind_presence_pip.dart';

/// Asserts the pumped widget tree satisfies rules R01–R04.
///
/// Every Mind surface test calls this. Without one shared assertion each of the
/// fourteen surfaces reimplements four checks, and four checks written
/// fourteen times is four checks that drift.
///
/// R05 is deliberately absent: it is a property of the build, not of a widget
/// tree, and `scripts/check-mind-private-devices.sh` enforces it.
Future<void> expectSatisfiesMindRules(
  WidgetTester tester, {
  /// Set false for a surface with no status strip — a modal sheet, a capture
  /// overlay. The default is true because the strip is the norm.
  bool expectsNumbers = true,
}) async {
  // R01 — presence.
  expect(
    find.byType(MindPresencePip),
    findsAtLeastNWidgets(1),
    reason: 'R01: every Mind surface states where the work ran.',
  );

  // R04 — numbers.
  if (expectsNumbers) {
    expect(
      find.byType(MindNumberStrip),
      findsAtLeastNWidgets(1),
      reason: 'R04: ops, peers and vault state stay visible.',
    );
  }

  // R02 — tags are tappable and meet the target. Surfaces with no tags pass
  // vacuously; surfaces with tags must have real ones.
  final chips = find.byType(MindContextChip);
  for (var i = 0; i < chips.evaluate().length; i++) {
    final chip = chips.at(i);
    expect(
      tester.getSize(chip).height,
      greaterThanOrEqualTo(MindContextChip.minimumTarget),
      reason: 'R02: a context chip below '
          '${MindContextChip.minimumTarget}px is one a person misses.',
    );
  }

  // R02, second half — no bare text that looks like a tag but is not one.
  final bareTags = find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.startsWith('#') ?? false),
  );
  for (var i = 0; i < bareTags.evaluate().length; i++) {
    final element = bareTags.evaluate().elementAt(i);
    final inChip = element
        .findAncestorWidgetOfExactType<MindContextChip>();
    expect(
      inChip,
      isNotNull,
      reason: 'R02: "${(element.widget as Text).data}" renders as a tag but '
          'is not a MindContextChip, so it is decoration.',
    );
  }
}
```

Create `packages/feature_mind/lib/testing.dart`:

```dart
/// Test-only surface for Airo Mind.
///
/// Separate from `feature_mind.dart` so that `flutter_test` never enters a
/// release build's dependency graph.
library;

export 'src/testing/mind_rule_harness.dart';
```

- [ ] **Step 4: Run the test**

Run: `cd packages/feature_mind && flutter test test/rules/harness_test.dart`

Expected: PASS, 3 tests.

- [ ] **Step 5: Run the whole package suite**

Run: `cd packages/feature_mind && flutter test`

Expected: PASS. This is the first run of every P0 test together.

- [ ] **Step 6: Analyze, format, commit**

```bash
cd packages/feature_mind && flutter analyze --fatal-infos && dart format --set-exit-if-changed .
cd ../.. && git add packages/feature_mind
git commit -m "feat(mind): one-line rule harness for R01-R04

Four checks written fourteen times is four checks that drift. The harness
carries its own mutation tests: a surface missing its pip must fail it,
and a bare '#tag' Text that is not a MindContextChip must fail it too.

Refs #1449"
```

---

### Task 13: Wire it up — dependencies, exports, CI, docs

The last task makes P0 real to the rest of the repo: the module manifest allows the new dependency, melos knows about the two gates, CI runs them, and the spec's status is updated.

**Files:**
- Modify: `packages/feature_mind/module.yaml`
- Modify: `packages/feature_mind/pubspec.yaml`
- Modify: `packages/feature_mind/lib/feature_mind.dart`
- Modify: `melos.yaml`
- Modify: `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`
- Create: `docs/adr/0021-mind-runtime-port.md`

**Interfaces:**
- Consumes: everything from Tasks 2–12.
- Produces: `melos run check:mind-rules`; ADR 0021 as the Contract Impact record the epic requires.

- [ ] **Step 1: Write the failing test**

Create `packages/feature_mind/test/module_contract_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the module manifest allows every dependency the pubspec declares', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final module = File('module.yaml').readAsStringSync();

    // First-party packages are the ones the manifest governs; pub.dev packages
    // are governed by the dependency scorecard instead.
    final firstParty = RegExp(r'^\s{2}(core_\w+|platform_\w+|feature_\w+):',
            multiLine: true)
        .allMatches(pubspec)
        .map((match) => match.group(1)!)
        .toSet();

    for (final dependency in firstParty) {
      expect(
        module,
        contains(dependency),
        reason: 'module.yaml must list $dependency in allowed_dependencies '
            'before the pubspec depends on it.',
      );
    }
  });

  test('the public library exports the runtime, not the bridge', () {
    final library = File('lib/feature_mind.dart').readAsStringSync();

    expect(library, contains("export 'src/runtime/mind_runtime.dart'"));
    expect(
      library,
      isNot(contains('frb_generated')),
      reason: 'The generated bridge is an implementation detail. Only '
          'rust_mind_runtime.dart may reach it.',
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd packages/feature_mind && flutter test test/module_contract_test.dart`

Expected: PASS on the second test, FAIL on the first once `core_ui` is added in step 3 — run it again after that step to see the failure the fix answers.

- [ ] **Step 3: Add `core_ui` and allow it**

In `packages/feature_mind/pubspec.yaml`, under `dependencies`:

```yaml
  # The Cyber palette and the three Airo faces already live here. Duplicating
  # them into this package would give Mind a second source of truth for colour.
  core_ui:
    path: ../core_ui
```

In `packages/feature_mind/module.yaml`:

```yaml
allowed_dependencies:
  - core_ui
```

Run `cd packages/feature_mind && flutter pub get`, then re-run the module contract test — it must now pass.

- [ ] **Step 4: Register the gates with melos**

In `melos.yaml`, alongside the existing scripts:

```yaml
  check:mind-rules:
    run: |
      scripts/check-mind-projection-routes.sh && \
      scripts/check-mind-private-devices.sh
    description: >
      Airo Mind rules R03 and R05. R03: graph, timeline and search are one
      switcher, never three routes. R05: no shared-surface flavor links
      feature_mind. Both carry mutation tests in packages/feature_mind/test/rules.
```

- [ ] **Step 5: Write the ADR**

Create `docs/adr/0021-mind-runtime-port.md`:

```markdown
# ADR 0021 — The MindRuntime port

Status: accepted
Date: 2026-08-02
Deciders: Chief Architect, Platform Architect, Chief Security Officer

## Context

Milestone 22 builds fourteen Mind surfaces. Milestone 19 has not shipped a
vault, an operation log, or a projection. Either the surfaces wait, or they
bind to something that is not the runtime.

## Decision

`packages/feature_mind` exposes `MindRuntime` — eight abstract sub-ports shaped
to the v1 architecture's seven primitives, contracts C1–C7 and six-function
API. Two implementations: `FixtureMindRuntime`, deterministic; and
`RustMindRuntime`, partial, throwing `MindPortUnavailable` per unimplemented
port.

Milestone 19 implements against the port. A runtime that cannot satisfy a port
method files a follow-up ADR rather than reshaping the port in place.

## Contract Impact

| Contract | Impact |
|---|---|
| C1 identity and device authorisation | `VaultPort` surfaces state and revocation only. No key material crosses the port. |
| C2 operation header and signing | `OperationLogPort.verify` returns a `SignatureState`, never a raw signature. |
| C3 content addressing | Not exposed. Surfaces address content through ops. |
| C4 revocation ordering | `VaultState.revocationEpoch` is the only ordering signal a surface sees. |
| C5 recovery package | `PortabilityPort` is the export flow. The format stays with #1305. |
| C6 replay determinism | `OperationLogPort.replayFrom` and `ProjectionPort.rebuild` both report progress, so a surface cannot assume instantaneous replay. |
| C7 projection disposability | `ProjectionState.lastRebuildMs` is measured, so the on-screen claim is checkable. |

No frozen surface changes. No new primitive.

## Consequences

Surfaces ship before the runtime, and every one of them already renders the
runtime-unavailable state, because that is the only state `RustMindRuntime`
produces today.

The risk is a port shaped by fixtures rather than by reality. The mitigation is
that milestone 19's issues are the port's first real consumer and every one of
them is reviewed against this ADR.
```

- [ ] **Step 6: Update the spec's status**

In `docs/superpowers/specs/2026-08-02-airo-mind-device-system-design.md`, change the status line:

```markdown
Status: P0 implemented, P1–P4 pending
```

and add under **Architecture → The port**:

```markdown
The port's Contract Impact table is `docs/adr/0021-mind-runtime-port.md`.
```

- [ ] **Step 7: Run everything**

```bash
cd packages/feature_mind && flutter test && flutter analyze --fatal-infos
cd ../.. && melos run check:mind-rules
cd app && flutter test
```

Expected: all green.

- [ ] **Step 8: Commit**

```bash
git add packages/feature_mind melos.yaml docs
git commit -m "chore(mind): wire P0 into the workspace

module.yaml allows core_ui, melos gains check:mind-rules, and ADR 0021
records the port's Contract Impact table so M19 implements against a
reviewed contract rather than a file someone wrote.

Closes #1449"
```

---

## Self-Review

**Spec coverage.** Every P0 deliverable in the epic maps to a task: the eight sub-ports and Contract Impact table (Tasks 3, 13), `FixtureMindRuntime` with the design's numbers (Tasks 4–5), `RustMindRuntime` throwing per port (Task 6), the five shared widgets (Tasks 7–10), the R01–R05 harness with mutation tests (Tasks 9, 11, 12), and #1203 (Task 1).

**Known gap, deliberate.** The epic's done-list says "five shared widgets exist with **golden** coverage". This plan gives all five widget tests but no golden files, because the repo has golden infrastructure in only two packages (`app/test/asset_gen`, `core_entitlements/test/goldens`) and standing up a third with no reference images is its own task. P1's first surface needs goldens anyway and should establish the pattern for the package then. **Flag this to the reviewer rather than silently dropping it.**

**Type consistency.** `MindContext.itemCount` / `opCount`, `MindOp.sequence`, `DeviceFingerprint(a, b, c)`, `MindPeer.opsBehind`, `ProjectionState.lastRebuildMs`, `ModelBench.measuredUnder`, `RecoveryPackagePlan.totalBytes` — each defined once in Task 2 and used with the same name in Tasks 4, 5, 7, 8, 10 and 12. `MindContextChip.minimumTarget` is defined in Task 8 and read by the harness in Task 12. `MindRuntime.portNames` is defined in Task 3 and asserted there.

**One duplication accepted.** Thousands-grouping appears in both `MindNumberStrip` and `MindOpRow` (Tasks 7 and 10). Task 10 names it and states the extraction trigger: a third caller.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-02-airo-mind-p0-contract.md`.
