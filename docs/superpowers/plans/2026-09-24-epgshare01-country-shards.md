# EPGShare01 country shards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Picking a country in Settings/browse downloads that country's EPGShare01 gzip via published `airo_epg` 1.2.0; the 192 MB ALL_SOURCES file is rejected before inflate.

**Architecture:** `airo_epg` owns the ISO→filename allow-list, banned-URL check, and 16 MiB / 80 MiB caps (no HTTP). Aika Stream `XmltvSourceRefreshService` downloads with those guards. A keep-alive coordinator watches `channelFiltersProvider.country` (same key as Settings) and fetches `XmltvSourceKind.system` only when no user XMLTV URL is saved. Cloudflare / R2 is unused.

**Tech Stack:** Dart 3.12 / Flutter tests in sibling `/Users/udaychauhan/workspace/airo_epg`, pub `airo_epg` 1.2.0, Airo `platform_epg` shim, `feature_iptv` Dio refresh, Riverpod listen.

**Spec:** `docs/superpowers/specs/2026-09-24-epgshare01-country-shards-design.md`

**Repos:** Implement Tasks 1–5 in `../airo_epg` (clone if missing). Tasks 7–12 in Airo on a branch from `origin/main` (`agent/media-intelligence/epgshare01-country-shards`). Do not implement from leftover `agent/iptv/aika-stream-002-21`.

If `../airo_epg` is missing:

```bash
git clone https://github.com/DevelopersCoffee/airo_epg.git /Users/udaychauhan/workspace/airo_epg
```

Work on `airo_epg` `main` (1.0.0 published). Do not mix `feat/xmltv-naive-offset` (1.1.0) into this cut.

---

## File map

| File | Responsibility |
| --- | --- |
| `../airo_epg/lib/src/epgshare01_country_shard.dart` | ISO → `https://epgshare01.online/epgshare01/epg_ripper_{slug}.xml.gz` |
| `../airo_epg/lib/src/xmltv_ingest_guard.dart` | Banned URLs, byte caps, capped gunzip |
| `../airo_epg/lib/platform_epg.dart` | Export new types |
| `../airo_epg/pubspec.yaml` | `1.2.0` |
| `packages/platform_epg/pubspec.yaml` | `airo_epg: ^1.2.0` |
| `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart` | Guard before/during download; 120s timeout; capped gunzip |
| `packages/feature_iptv/lib/application/country_xmltv_guide_coordinator.dart` | Country → system refresh |
| `packages/feature_iptv/lib/application/providers/guide_providers.dart` | Sync provider |
| `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` | `ref.watch` so sync runs |
| `PRIVACY.md`, `docs/release/AIKA_STREAM_PLAY_STORE_GATE.md` | One privacy sentence |

Do not edit `.github/workflows/iptv_guide_r2.yml`, split-view handle, `TvFontMode`, or `pubspec_tv.yaml` versionCode.

---

### Task 1: `Epgshare01CountryShard` failing tests (`airo_epg`)

**Files:**
- Create: `/Users/udaychauhan/workspace/airo_epg/test/epgshare01_country_shard_test.dart`
- Create: `/Users/udaychauhan/workspace/airo_epg/lib/src/epgshare01_country_shard.dart` (empty stub only if the test import fails to compile — prefer test-first, then stub)

- [ ] **Step 1: Write the failing test**

```dart
import 'package:airo_epg/platform_epg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IN resolves to IN1 gzip', () {
    expect(
      Epgshare01CountryShard.resolve('IN').toString(),
      'https://epgshare01.online/epgshare01/epg_ripper_IN1.xml.gz',
    );
  });

  test('in is case-insensitive', () {
    expect(
      Epgshare01CountryShard.resolve('in'),
      Epgshare01CountryShard.resolve('IN'),
    );
  });

  test('GB and UK both resolve to UK1', () {
    expect(
      Epgshare01CountryShard.resolve('GB').toString(),
      'https://epgshare01.online/epgshare01/epg_ripper_UK1.xml.gz',
    );
    expect(
      Epgshare01CountryShard.resolve('UK'),
      Epgshare01CountryShard.resolve('GB'),
    );
  });

  test('US resolves to US2 not US_LOCALS', () {
    expect(
      Epgshare01CountryShard.resolve('US').path,
      endsWith('epg_ripper_US2.xml.gz'),
    );
  });

  test('CA resolves to CA2', () {
    expect(
      Epgshare01CountryShard.resolve('CA').path,
      endsWith('epg_ripper_CA2.xml.gz'),
    );
  });

  test('unknown country throws XmltvShardUnavailableException', () {
    expect(
      () => Epgshare01CountryShard.resolve('ZZ'),
      throwsA(isA<XmltvShardUnavailableException>()),
    );
    expect(
      () => Epgshare01CountryShard.resolve(''),
      throwsA(isA<XmltvShardUnavailableException>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/epgshare01_country_shard_test.dart`

Expected: FAIL (undefined class `Epgshare01CountryShard`).

- [ ] **Step 3: Minimal stub so the test compiles and still fails assertions if resolve is empty**

Do not put the real map yet if you prefer a single GREEN in Task 2. Allowed: empty class that throws on every call — then Task 1 RED is "throws for IN". Prefer implementing in Task 2 immediately after this RED.

- [ ] **Step 4: Commit** (airo_epg repo)

```bash
cd /Users/udaychauhan/workspace/airo_epg
git add test/epgshare01_country_shard_test.dart
git commit -m "$(cat <<'EOF'
test(epg): fail until EPGShare01 country shards resolve

EOF
)"
```

---

### Task 2: Implement `Epgshare01CountryShard`

**Files:**
- Create: `/Users/udaychauhan/workspace/airo_epg/lib/src/epgshare01_country_shard.dart`
- Modify: `/Users/udaychauhan/workspace/airo_epg/lib/platform_epg.dart`

- [ ] **Step 1: Add types + resolver**

```dart
class XmltvShardUnavailableException implements Exception {
  const XmltvShardUnavailableException(this.countryCode);

  final String countryCode;

  @override
  String toString() => 'No EPGShare01 guide file for $countryCode.';
}

class Epgshare01CountryShard {
  static const baseUrl = 'https://epgshare01.online/epgshare01/';

  /// Largest two-letter country gzip on the 2026-09-23 EPGShare01 index.
  /// `GB` is an alias of `UK` (applied before lookup).
  static const slugs = <String, String>{
    'AE': 'AE1',
    'AL': 'AL1',
    'AR': 'AR1',
    'AT': 'AT1',
    'AU': 'AU1',
    'BA': 'BA1',
    'BB': 'BB1',
    'BE': 'BE2',
    'BG': 'BG1',
    'BR': 'BR1',
    'CA': 'CA2',
    'CH': 'CH1',
    'CL': 'CL1',
    'CO': 'CO1',
    'CR': 'CR1',
    'CY': 'CY1',
    'CZ': 'CZ1',
    'DE': 'DE1',
    'DK': 'DK1',
    'DO': 'DO1',
    'EC': 'EC1',
    'EG': 'EG1',
    'ES': 'ES1',
    'FI': 'FI1',
    'FR': 'FR1',
    'GR': 'GR1',
    'HK': 'HK1',
    'HR': 'HR1',
    'HU': 'HU1',
    'ID': 'ID1',
    'IE': 'IE1',
    'IL': 'IL1',
    'IN': 'IN1',
    'IT': 'IT1',
    'JM': 'JM1',
    'JP': 'JP1',
    'KE': 'KE1',
    'KR': 'KR1',
    'KZ': 'KZ1',
    'LT': 'LT1',
    'LU': 'LU1',
    'LV': 'LV1',
    'MN': 'MN1',
    'MT': 'MT1',
    'MX': 'MX1',
    'MY': 'MY1',
    'NG': 'NG1',
    'NL': 'NL1',
    'NO': 'NO1',
    'NZ': 'NZ1',
    'PA': 'PA1',
    'PE': 'PE1',
    'PH': 'PH2',
    'PK': 'PK1',
    'PL': 'PL1',
    'PT': 'PT1',
    'RO': 'RO1',
    'RS': 'RS1',
    'SA': 'SA2',
    'SE': 'SE1',
    'SG': 'SG1',
    'SK': 'SK1',
    'SV': 'SV1',
    'TH': 'TH1',
    'TR': 'TR3',
    'UK': 'UK1',
    'US': 'US2',
    'UY': 'UY1',
    'VN': 'VN1',
    'ZA': 'ZA1',
  };

  static Uri resolve(String countryCode) {
    var code = countryCode.trim().toUpperCase();
    if (code == 'GB') code = 'UK';
    final slug = slugs[code];
    if (slug == null) {
      throw XmltvShardUnavailableException(countryCode);
    }
    return Uri.parse('${baseUrl}epg_ripper_$slug.xml.gz');
  }
}
```

Export:

```dart
export 'src/epgshare01_country_shard.dart';
```

from `/Users/udaychauhan/workspace/airo_epg/lib/platform_epg.dart` (append; keep existing exports).

- [ ] **Step 2: Run tests**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/epgshare01_country_shard_test.dart`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
cd /Users/udaychauhan/workspace/airo_epg
git add lib/src/epgshare01_country_shard.dart lib/platform_epg.dart test/epgshare01_country_shard_test.dart
git commit -m "$(cat <<'EOF'
feat(epg): resolve EPGShare01 country shard URLs

EOF
)"
```

---

### Task 3: Ingest guard failing tests (`airo_epg`)

**Files:**
- Create: `/Users/udaychauhan/workspace/airo_epg/test/xmltv_ingest_guard_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:airo_epg/platform_epg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('assertSafeUrl accepts IN1', () {
    expect(
      () => XmltvIngestGuard.assertSafeUrl(
        Uri.parse(
          'https://epgshare01.online/epgshare01/epg_ripper_IN1.xml.gz',
        ),
      ),
      returnsNormally,
    );
  });

  test('assertSafeUrl rejects ALL_SOURCES', () {
    expect(
      () => XmltvIngestGuard.assertSafeUrl(
        Uri.parse(
          'https://epgshare01.online/epgshare01/epg_ripper_ALL_SOURCES1.xml.gz',
        ),
      ),
      throwsA(isA<XmltvIngestBannedUrlException>()),
    );
  });

  test('assertSafeUrl rejects US_LOCALS', () {
    expect(
      () => XmltvIngestGuard.assertSafeUrl(
        Uri.parse(
          'https://epgshare01.online/epgshare01/epg_ripper_US_LOCALS1.xml.gz',
        ),
      ),
      throwsA(isA<XmltvIngestBannedUrlException>()),
    );
  });

  test('assertSafeLength rejects oversize compressed', () {
    expect(
      () => XmltvIngestGuard.assertSafeLength(
        compressedBytes: XmltvIngestGuard.maxCompressedBytes + 1,
      ),
      throwsA(isA<XmltvIngestTooLargeException>()),
    );
  });

  test('assertSafeLength rejects oversize uncompressed', () {
    expect(
      () => XmltvIngestGuard.assertSafeLength(
        compressedBytes: 100,
        uncompressedBytes: XmltvIngestGuard.maxUncompressedBytes + 1,
      ),
      throwsA(isA<XmltvIngestTooLargeException>()),
    );
  });

  test('gunzipFile aborts when uncompressed cap is exceeded', () async {
    final dir = await Directory.systemTemp.createTemp('xmltv_gunzip');
    final input = File('${dir.path}/in.gz');
    final output = File('${dir.path}/out.xml');
    final payload = List<int>.filled(
      XmltvIngestGuard.maxUncompressedBytes + 1,
      0x41,
    );
    await input.writeAsBytes(gzip.encode(payload), flush: true);
    await expectLater(
      XmltvIngestGuard.gunzipFile(input: input, output: output),
      throwsA(isA<XmltvIngestTooLargeException>()),
    );
    await dir.delete(recursive: true);
  });
}
```

Use `import 'dart:io';` for `gzip` (same as `xmltv_source_refresh_service.dart`).

- [ ] **Step 2: Run test to verify it fails**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/xmltv_ingest_guard_test.dart`

Expected: FAIL (undefined `XmltvIngestGuard`).

- [ ] **Step 3: Commit**

```bash
cd /Users/udaychauhan/workspace/airo_epg
git add test/xmltv_ingest_guard_test.dart
git commit -m "$(cat <<'EOF'
test(epg): fail until XMLTV ingest size and URL guards exist

EOF
)"
```

---

### Task 4: Implement ingest guard

**Files:**
- Create: `/Users/udaychauhan/workspace/airo_epg/lib/src/xmltv_ingest_guard.dart`
- Modify: `/Users/udaychauhan/workspace/airo_epg/lib/platform_epg.dart`

- [ ] **Step 1: Implement**

```dart
import 'dart:io';

class XmltvIngestBannedUrlException implements Exception {
  const XmltvIngestBannedUrlException();

  @override
  String toString() =>
      'Pick a country in Settings. Do not use the world ALL_SOURCES file.';
}

class XmltvIngestTooLargeException implements Exception {
  const XmltvIngestTooLargeException();

  @override
  String toString() =>
      'This guide file is too large to load on this device. Pick a country '
      'guide instead of a world file.';
}

class XmltvIngestGuard {
  static const maxCompressedBytes = 16 * 1024 * 1024;
  static const maxUncompressedBytes = 80 * 1024 * 1024;

  static const _banned = [
    'all_sources',
    'guide_all',
    'us_locals',
    'dummy_channels',
  ];

  static void assertSafeUrl(Uri url) {
    if (url.host.isEmpty ||
        (url.scheme != 'https' && url.scheme != 'http')) {
      throw ArgumentError.value(url, 'url', 'Enter a valid HTTP(S) XMLTV URL.');
    }
    final haystack = '${url.path} ${url.query}'.toLowerCase();
    for (final token in _banned) {
      if (haystack.contains(token)) {
        throw const XmltvIngestBannedUrlException();
      }
    }
  }

  static void assertSafeLength({
    required int compressedBytes,
    int? uncompressedBytes,
  }) {
    if (compressedBytes > maxCompressedBytes) {
      throw const XmltvIngestTooLargeException();
    }
    if (uncompressedBytes != null &&
        uncompressedBytes > maxUncompressedBytes) {
      throw const XmltvIngestTooLargeException();
    }
  }

  static Future<void> gunzipFile({
    required File input,
    required File output,
    int maxUncompressedBytes = XmltvIngestGuard.maxUncompressedBytes,
  }) async {
    final sink = output.openWrite();
    var written = 0;
    try {
      await for (final chunk in gzip.decoder.bind(input.openRead())) {
        written += chunk.length;
        if (written > maxUncompressedBytes) {
          throw const XmltvIngestTooLargeException();
        }
        sink.add(chunk);
      }
      await sink.close();
    } catch (_) {
      await sink.close();
      if (await output.exists()) await output.delete();
      rethrow;
    }
  }
}
```

Export `src/xmltv_ingest_guard.dart` from `platform_epg.dart`.

The oversize gunzip test allocates ~80 MiB. If the test host OOMs, shrink the test cap:

```dart
await XmltvIngestGuard.gunzipFile(
  input: input,
  output: output,
  maxUncompressedBytes: 1024,
);
```

with a 2048-byte uncompressed payload. Production code keeps 80 MiB default.

- [ ] **Step 2: Run tests**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/xmltv_ingest_guard_test.dart test/epgshare01_country_shard_test.dart`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
cd /Users/udaychauhan/workspace/airo_epg
git add lib/src/xmltv_ingest_guard.dart lib/platform_epg.dart test/xmltv_ingest_guard_test.dart
git commit -m "$(cat <<'EOF'
feat(epg): reject ALL_SOURCES and oversize XMLTV before parse

EOF
)"
```

---

### Task 5: Version 1.2.0 and changelog (`airo_epg`)

**Files:**
- Modify: `/Users/udaychauhan/workspace/airo_epg/pubspec.yaml` (`version: 1.2.0`)
- Modify: `/Users/udaychauhan/workspace/airo_epg/CHANGELOG.md`

- [ ] **Step 1: Bump and describe**

`pubspec.yaml` `version: 1.2.0`

CHANGELOG:

```markdown
## 1.2.0

- Resolve EPGShare01 per-country XMLTV shard URLs from an ISO allow-list.
- Reject ALL_SOURCES / oversized XMLTV URLs and cap gzip inflate.
```

Keep the existing `## 1.0.0` section.

- [ ] **Step 2: Full package tests**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test`

Expected: PASS (existing suite + new files).

- [ ] **Step 3: Commit**

```bash
cd /Users/udaychauhan/workspace/airo_epg
git add pubspec.yaml CHANGELOG.md
git commit -m "$(cat <<'EOF'
chore(epg): release 1.2.0 country shards and ingest guards

EOF
)"
```

- [ ] **Step 4: Push `airo_epg` `main`** (needs network / human if protected)

```bash
cd /Users/udaychauhan/workspace/airo_epg
git push origin HEAD
```

---

### Task 6: Publish `airo_epg` 1.2.0 to pub.dev

- [ ] **Step 1: Publish**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart pub publish`

Expected: package `airo_epg` 1.2.0 on pub.dev.

If publish is blocked, stop and ask. Do not pin Airo to an unpublished version in a committed `pubspec.yaml`. A **temporary uncommitted** path override for local Airo work is allowed:

```yaml
# do not commit
dependency_overrides:
  airo_epg:
    path: ../../airo_epg
```

at the workspace root only while Task 7 waits on pub.dev.

---

### Task 7: Pin `platform_epg` to `airo_epg` ^1.2.0

**Files:**
- Modify: `packages/platform_epg/pubspec.yaml`

- [ ] **Step 1: Constraint**

Change `airo_epg: ^1.0.0` to `airo_epg: ^1.2.0`.

- [ ] **Step 2: Resolve**

Run: `cd /Users/udaychauhan/workspace/airo && dart pub get`

Expected: `airo_epg` 1.2.0 (or 1.2.x) in the lockfile.

- [ ] **Step 3: Commit** (Airo repo)

```bash
git add packages/platform_epg/pubspec.yaml pubspec.lock
git commit -m "$(cat <<'EOF'
chore(platform_epg): pin airo_epg 1.2.0

EOF
)"
```

(`pubspec.lock` only if the workspace records it.)

---

### Task 8: Refresh-service guard tests (`feature_iptv`)

**Files:**
- Modify: `packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart`

- [ ] **Step 1: Add tests at the end of `main()`** (same `setUp` / `service`)

```dart
  test('refresh rejects ALL_SOURCES before download', () async {
    await expectLater(
      () => service.refresh(
        'https://epgshare01.online/epgshare01/epg_ripper_ALL_SOURCES1.xml.gz',
      ),
      throwsA(isA<XmltvIngestBannedUrlException>()),
    );
    expect(await sourceStore.loadAll(), isEmpty);
  });

  test('refreshCountryShard uses IN1 as system source', () async {
    await service.refreshCountryShard('IN');
    final source = (await sourceStore.loadAll()).single;
    expect(
      source.url,
      'https://epgshare01.online/epgshare01/epg_ripper_IN1.xml.gz',
    );
    expect(source.kind, XmltvSourceKind.system);
  });
```

`_FakeXmltvAdapter` already serves XML for any URL; IN1 `.gz` suffix still hits the fake unless the adapter checks path. If the fake writes XML (not gzip) for `.gz` URLs, `_isGzip` uses the `.gz` suffix and gunzip will fail. For `refreshCountryShard` use an adapter that returns gzip bytes (copy the existing gzip test adapter) **or** make `refreshCountryShard` tests mock at the service method after taping `refresh`.

Preferred: implement `refreshCountryShard` as:

```dart
Future<void> refreshCountryShard(String country) async {
  final uri = Epgshare01CountryShard.resolve(country);
  await refresh(uri.toString(), kind: XmltvSourceKind.system);
}
```

and in the test, use `_BytesXmltvAdapter(gzip.encode(utf8.encode(_minimalXmltv)))` for that service instance (same pattern as the existing gzip test).

- [ ] **Step 2: Run to verify fail**

Run: `cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`

Expected: FAIL (`refreshCountryShard` missing and/or ALL_SOURCES still downloads).

- [ ] **Step 3: Commit**

```bash
git add packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart
git commit -m "$(cat <<'EOF'
test(iptv): fail until country shard refresh rejects ALL_SOURCES

EOF
)"
```

---

### Task 9: Guard download + `refreshCountryShard`

**Files:**
- Modify: `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart`

- [ ] **Step 1: At the start of `refresh`, after URI scheme validation**

```dart
XmltvIngestGuard.assertSafeUrl(uri);
```

(`uri` is the parsed `Uri` already in `refresh`.)

- [ ] **Step 2: In `_downloadAndParse`**

1. `XmltvIngestGuard.assertSafeUrl(Uri.parse(url));`
2. `receiveTimeout: const Duration(seconds: 120)`
3. `onReceiveProgress: (received, total) { XmltvIngestGuard.assertSafeLength(compressedBytes: received); if (total > 0) XmltvIngestGuard.assertSafeLength(compressedBytes: total); }`
4. After download: `XmltvIngestGuard.assertSafeLength(compressedBytes: await downloadFile.length());`
5. Replace `gzip.decoder.bind(...).pipe(...)` with:

```dart
await XmltvIngestGuard.gunzipFile(
  input: downloadFile,
  output: guideFile,
);
```

(`AiroWorkerExecutor` may still wrap that call so inflate stays off the UI isolate.)

- [ ] **Step 3: Add `refreshCountryShard`** as in Task 8.

- [ ] **Step 4: Run tests**

Run: `cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`

Expected: PASS (old tests + new).

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart
git commit -m "$(cat <<'EOF'
feat(iptv): cap XMLTV download and refresh EPGShare01 country shards

EOF
)"
```

---

### Task 10: Coordinator tests

**Files:**
- Create: `packages/feature_iptv/lib/application/country_xmltv_guide_coordinator.dart` (after GREEN, not before — write tests against the public API first using a fake refresh)
- Create: `packages/feature_iptv/test/iptv/application/country_xmltv_guide_coordinator_test.dart`

- [ ] **Step 1: Write tests with a recording fake**

```dart
import 'package:feature_iptv/application/country_xmltv_guide_coordinator.dart';
import 'package:feature_iptv/application/xmltv_source_refresh_service.dart';
import 'package:feature_iptv/application/xmltv_source_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:core_data/core_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingRefresh {
  final calls = <String>[];
  Future<void> refreshCountryShard(String country) async {
    calls.add(country);
  }
}

void main() {
  late XmltvSourceStore store;
  late CountryXmltvGuideCoordinator coordinator;
  late _RecordingRefresh refresh;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = XmltvSourceStore(PreferencesStore(prefs));
    refresh = _RecordingRefresh();
    coordinator = CountryXmltvGuideCoordinator(
      sourceStore: store,
      refreshCountryShard: refresh.refreshCountryShard,
    );
  });

  test('null country does not fetch', () async {
    await coordinator.sync(country: null);
    expect(refresh.calls, isEmpty);
  });

  test('IN fetches once as country shard', () async {
    await coordinator.sync(country: 'IN');
    expect(refresh.calls, ['IN']);
  });

  test('user XMLTV skips country fetch', () async {
    await store.save(
      const XmltvSourceConfig(
        url: 'https://example.com/user.xml',
        kind: XmltvSourceKind.user,
      ),
    );
    await coordinator.sync(country: 'IN');
    expect(refresh.calls, isEmpty);
  });
}
```

If injecting a tear-off is awkward, give `CountryXmltvGuideCoordinator` a typedef:

```dart
typedef RefreshCountryShard = Future<void> Function(String country);
```

- [ ] **Step 2: Run — expect FAIL** (missing class)

Run: `cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && flutter test test/iptv/application/country_xmltv_guide_coordinator_test.dart`

- [ ] **Step 3: Commit failing test**

```bash
git add packages/feature_iptv/test/iptv/application/country_xmltv_guide_coordinator_test.dart
git commit -m "$(cat <<'EOF'
test(iptv): fail until country EPG coordinator skips user paste

EOF
)"
```

---

### Task 11: Coordinator + shell watch

**Files:**
- Create: `packages/feature_iptv/lib/application/country_xmltv_guide_coordinator.dart`
- Modify: `packages/feature_iptv/lib/application/providers/guide_providers.dart`
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart` (`build` ~line 156)

- [ ] **Step 1: Implement coordinator**

```dart
import 'xmltv_source_store.dart';

typedef RefreshCountryShard = Future<void> Function(String country);

class CountryXmltvGuideCoordinator {
  CountryXmltvGuideCoordinator({
    required this.sourceStore,
    required this.refreshCountryShard,
  });

  final XmltvSourceStore sourceStore;
  final RefreshCountryShard refreshCountryShard;

  String? _lastFetchedCountry;

  Future<void> sync({required String? country}) async {
    final code = country?.trim();
    if (code == null || code.isEmpty) return;
    final sources = await sourceStore.loadAll();
    if (sources.any((source) => source.kind == XmltvSourceKind.user)) {
      return;
    }
    if (_lastFetchedCountry == code.toUpperCase()) return;
    await refreshCountryShard(code);
    _lastFetchedCountry = code.toUpperCase();
  }
}
```

Do **not** skip when a previous **system** source exists for a *different* country — IN→US must fetch. `_lastFetchedCountry` prevents listen duplicates. After a successful fetch, changing IN→US updates `_lastFetchedCountry`. Clearing country (`null`) does not fetch and does not clear the stored system guide.

If `refreshCountryShard` throws, do not set `_lastFetchedCountry` so a later retry can run.

- [ ] **Step 2: Providers in `guide_providers.dart`**

```dart
final countryXmltvGuideCoordinatorProvider =
    Provider<CountryXmltvGuideCoordinator>((ref) {
  return CountryXmltvGuideCoordinator(
    sourceStore: ref.watch(xmltvSourceStoreProvider),
    refreshCountryShard: (country) => ref
        .read(xmltvSourceRefreshServiceProvider)
        .refreshCountryShard(country),
  );
});

/// Keep-alive: first-run prompt and Settings both write
/// [channelFiltersProvider.country], so this is the single fetch edge.
final countryXmltvGuideSyncProvider = Provider<void>((ref) {
  ref.listen<String?>(
    channelFiltersProvider.select((filters) => filters.country),
    (previous, next) {
      unawaited(
        ref.read(countryXmltvGuideCoordinatorProvider).sync(country: next),
      );
    },
    fireImmediately: true,
  );
});
```

Add `import 'dart:async';` if `unawaited` is not already in scope.

- [ ] **Step 3: In `AiroTvShell.build` immediately after `final filters = ref.watch(channelFiltersProvider);`**

```dart
    ref.watch(countryXmltvGuideSyncProvider);
```

Import `guide_providers.dart` if needed.

Phone and TV both use `AiroTvShell` from `iptv_screen.dart` — do not add a second watch.

- [ ] **Step 4: Run coordinator tests + refresh tests**

Run:

```bash
cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && flutter test \
  test/iptv/application/country_xmltv_guide_coordinator_test.dart \
  test/iptv/application/xmltv_source_refresh_service_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add packages/feature_iptv/lib/application/country_xmltv_guide_coordinator.dart \
  packages/feature_iptv/lib/application/providers/guide_providers.dart \
  packages/feature_iptv/lib/presentation/tv_ux/airo_tv_shell.dart \
  packages/feature_iptv/test/iptv/application/country_xmltv_guide_coordinator_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): load EPGShare01 guide when the country picker is set

EOF
)"
```

---

### Task 12: Privacy and Play gate

**Files:**
- Modify: `PRIVACY.md` (Network Access list)
- Modify: `docs/release/AIKA_STREAM_PLAY_STORE_GATE.md` (First Play dart-defines row note)

- [ ] **Step 1: PRIVACY.md — add under Network Access**

```markdown
- Download a programme-guide (XMLTV) file for the country the user picks in Settings, or for a guide URL the user pastes. The app does not download a world-wide guide dump.
```

Do not name EPGShare01 as a vendor in the Play listing. Do not enable `IPTV_DATA_MANIFEST_URL`.

- [ ] **Step 2: Play gate table — add a row after dart-defines**

```markdown
| Country XMLTV | Device fetches one EPGShare01 country gzip when Settings country is set and the user has not pasted an XMLTV URL. Never ALL_SOURCES. Privacy names country/pasted XMLTV only. |
```

Leave `IPTV_DATA_MANIFEST_URL` **unset**.

- [ ] **Step 3: Commit**

```bash
git add PRIVACY.md docs/release/AIKA_STREAM_PLAY_STORE_GATE.md
git commit -m "$(cat <<'EOF'
docs(privacy): disclose country programme-guide download

EOF
)"
```

Use `[skip ci]` only if the commit-msg hook allows docs-only; this touches PRIVACY which may be treated as product. Do not skip if the hook rejects it.

---

### Task 13: Format and analyze

- [ ] **Step 1: Format**

```bash
cd /Users/udaychauhan/workspace/airo_epg && dart format lib test
cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && dart format lib test
cd /Users/udaychauhan/workspace/airo/packages/platform_epg && dart format .
```

- [ ] **Step 2: Analyze**

```bash
cd /Users/udaychauhan/workspace/airo_epg && dart analyze
cd /Users/udaychauhan/workspace/airo/packages/feature_iptv && flutter analyze
```

Expected: no new errors.

- [ ] **Step 3: Commit format-only if needed**

```bash
git commit -m "$(cat <<'EOF'
style(iptv): format country EPG ingest

EOF
)"
```

---

## Spec coverage

| Spec item | Task |
| --- | --- |
| Allow-list ISO → slug, GB→UK, US→US2 | 1–2 |
| Ban ALL_SOURCES / US_LOCALS / caps | 3–4, 8–9 |
| `airo_epg` 1.2.0, no Dio | 5–6 |
| `platform_epg` pin | 7 |
| 120s timeout, abort oversize download | 9 |
| Country picker only, no locale | 10–11 |
| Skip fetch if user XMLTV saved | 10–11 |
| Empty country does not fetch / does not clear last guide | 11 |
| Single fetch edge (Settings = `setCountry`) | 11 `listen` + `fireImmediately` |
| Privacy sentence, no R2 dart-define | 12 |
| No handle / fonts / resolution / timezone 1.1.0 | omitted |

## Execution handoff

Plan complete and saved to `docs/superpowers/plans/2026-09-24-epgshare01-country-shards.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
