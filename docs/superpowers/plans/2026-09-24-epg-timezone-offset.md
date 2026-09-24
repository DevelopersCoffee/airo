# EPG timezone offset Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Naked XMLTV stamps (no `+ZZZZ`) ingest as civil time in the device zone and store UTC, so Guide `.toLocal()` matches the sofa clock; tagged stamps stay unchanged.

**Architecture:** ICAST `naiveOffset` on `airo_epg` `parseXmltvTimestamp` / `fromXmltv*`. Aika Stream `XmltvSourceRefreshService` passes `DateTime.now().timeZoneOffset`. No Settings row. Rust `airo_core` timestamp helper gets the same rule for when native ingest is live.

**Tech Stack:** Dart `DateTime.timeZoneOffset` (no new timezone package), `airo_epg` 1.0.0 → 1.1.0, `platform_epg` pin, `feature_iptv` refresh.

**Design:** `docs/superpowers/specs/2026-09-24-epg-timezone-offset-design.md`

## Global Constraints

- Canonical store remains UTC. Display stays `.toLocal()`.
- Tagged `+HHMM` / `-HHMM` wins. `naiveOffset` applies only when the stamp has no offset group.
- `naiveOffset == null` keeps today's behavior (naked = UTC) for other `airo_epg` consumers.
- Aika Stream always passes a non-null device offset at refresh.
- No Sources / Playback / Accessibility timezone control.
- Do not add `timezone` or `flutter_timezone`.
- Do not regex-rewrite XMLTV. Do not duplicate the parser in `feature_iptv`.
- TDD. Skip commits unless the user asked.
- `airo_epg` is **not** in this monorepo (`https://github.com/DevelopersCoffee/airo_epg`, pub `airo_epg: ^1.0.0`). Clone a sibling checkout to implement Tasks 1–2. Airo Tasks 4–5 need that version via path override, git ref, or published `^1.1.0`.
- Base Airo work on `origin/main` after sleep timer (#2046).

---

## File structure

```
# sibling clone (Tasks 1–2)
../airo_epg/lib/src/xmltv_compact_epg_repository.dart
../airo_epg/lib/src/xmltv_parser.dart
../airo_epg/test/xmltv_compact_epg_repository_test.dart
../airo_epg/pubspec.yaml                                      # 1.0.0 → 1.1.0

# this repo
rust/airo_core/src/api/xmltv.rs
packages/platform_epg/pubspec.yaml
packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart
packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart
```

Sign convention (same as current `+HHMM`): east of UTC **subtracts**. Device `timeZoneOffset` for IST is `+5:30`, so naked `20260715090000` → `03:30Z`.

---

### Task 1: `parseXmltvTimestamp` naiveOffset (airo_epg)

**Files:**
- Modify: `../airo_epg/lib/src/xmltv_compact_epg_repository.dart` (`parseXmltvTimestamp`)
- Modify: `../airo_epg/lib/src/xmltv_parser.dart` (`_parseXmltvTimestamp` — lockstep)
- Modify: `../airo_epg/test/xmltv_compact_epg_repository_test.dart`
- Modify: `../airo_epg/pubspec.yaml` version `1.1.0`

**Setup:** If `../airo_epg` is missing:

```bash
git clone https://github.com/DevelopersCoffee/airo_epg.git /Users/udaychauhan/workspace/airo_epg
```

Work on branch `feat/xmltv-naive-offset` from that repo's default branch.

- [ ] **Step 1: Write the failing tests**

Append inside the existing timestamp test group (next to `parses valid XMLTV timestamps with offsets and rejects invalid values`):

```dart
    test('naked stamp with naiveOffset uses device zone, tagged ignores it', () {
      const ist = Duration(hours: 5, minutes: 30);
      expect(
        parseXmltvTimestamp('20260715090000', naiveOffset: ist),
        DateTime.utc(2026, 7, 15, 3, 30),
      );
      expect(
        parseXmltvTimestamp('20260715090000'),
        DateTime.utc(2026, 7, 15, 9),
      );
      expect(
        parseXmltvTimestamp(
          '20260715090000 +0000',
          naiveOffset: ist,
        ),
        DateTime.utc(2026, 7, 15, 9),
      );
      expect(
        parseXmltvTimestamp(
          '20260715143000 +0530',
          naiveOffset: const Duration(hours: -4),
        ),
        DateTime.utc(2026, 7, 15, 9),
      );
    });
```

- [ ] **Step 2: Run tests to fail**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/xmltv_compact_epg_repository_test.dart`

Expected: FAIL compiling (`naiveOffset` not defined).

- [ ] **Step 3: Implement parse**

Replace `parseXmltvTimestamp` in `xmltv_compact_epg_repository.dart` with:

```dart
DateTime? parseXmltvTimestamp(String value, {Duration? naiveOffset}) {
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})(?:\s*([+-])(\d{2})(\d{2}))?$',
  ).firstMatch(value.trim());
  if (match == null) return null;

  try {
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);
    if (!_isValidUtcComponent(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      second: second,
    )) {
      return null;
    }
    final civil = DateTime.utc(year, month, day, hour, minute, second);
    final sign = match.group(7);
    if (sign != null) {
      final offset = Duration(
        hours: int.parse(match.group(8)!),
        minutes: int.parse(match.group(9)!),
      );
      return sign == '+' ? civil.subtract(offset) : civil.add(offset);
    }
    if (naiveOffset != null) {
      return civil.subtract(naiveOffset);
    }
    return civil;
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}
```

Give `_parseXmltvTimestamp` in `xmltv_parser.dart` the same signature and body (keep the function private; it must not drift).

Bump `version:` in `../airo_epg/pubspec.yaml` to `1.1.0`.

- [ ] **Step 4: Re-run tests**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/xmltv_compact_epg_repository_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit** (skip unless asked)

```bash
git add lib/src/xmltv_compact_epg_repository.dart lib/src/xmltv_parser.dart \
  test/xmltv_compact_epg_repository_test.dart pubspec.yaml
git commit -m "$(cat <<'EOF'
feat(xmltv): interpret naked timestamps in an optional device offset

EOF
)"
```

---

### Task 2: Thread `naiveOffset` through ingest factories

**Files:**
- Modify: `../airo_epg/lib/src/xmltv_compact_epg_repository.dart` (`fromXmltv`, `fromXmltvFile`, `fromXmltvFileNative`, `fromXmltvCurrentNextFileNative`, `_fromNativeResult`, `_compactProgramFromNative`)

- [ ] **Step 1: Write a failing ingest test**

In the same airo_epg test file, add:

```dart
    test('fromXmltv applies naiveOffset only to naked programme stamps', () async {
      const xml = '''
<tv>
  <programme channel="chan-1" start="20260717120000" stop="20260717123000">
    <title>Naked</title>
  </programme>
  <programme channel="chan-1" start="20260717130000 +0000" stop="20260717133000 +0000">
    <title>Tagged</title>
  </programme>
</tv>
''';
      final repository = XmltvCompactEpgRepository.fromXmltv(
        content: xml,
        ingestedAt: DateTime.utc(2026, 7, 17, 6),
        naiveOffset: const Duration(hours: 5, minutes: 30),
      );
      final duringNaked = await repository.loadCurrentNext(
        channelIds: const ['chan-1'],
        now: DateTime.utc(2026, 7, 17, 6, 40),
      );
      expect(duringNaked.entryForChannel('chan-1')?.current?.title, 'Naked');
      final duringTagged = await repository.loadCurrentNext(
        channelIds: const ['chan-1'],
        now: DateTime.utc(2026, 7, 17, 13, 10),
      );
      expect(duringTagged.entryForChannel('chan-1')?.current?.title, 'Tagged');
    });
```

Naked `12:00` with IST `+5:30` → `06:30Z` (current at 06:40Z). Tagged `13:00 +0000` ignores the device offset → `13:00Z` (current at 13:10Z). If naiveOffset were wrongly applied to tagged, 13:00 would become 07:30Z and 13:10Z would miss it.

- [ ] **Step 2: Run to fail**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test test/xmltv_compact_epg_repository_test.dart`

Expected: FAIL (`naiveOffset` named arg missing on `fromXmltv`).

- [ ] **Step 3: Thread the argument**

Add `{Duration? naiveOffset}` to `fromXmltv`, `fromXmltvFile`, `fromXmltvFileNative`, `fromXmltvCurrentNextFileNative`. Pass it into `_fromNativeResult`. In `_fromNativeResult` and `_compactProgramFromNative`, call `parseXmltvTimestamp(..., naiveOffset: naiveOffset)`.

In `xmltv_parser.dart`, any `currentNext` path that calls `_parseXmltvTimestamp` must take the same `naiveOffset` so current/next cannot drift from the compact repository.

- [ ] **Step 4: Re-run tests**

Run: `cd /Users/udaychauhan/workspace/airo_epg && dart test`

Expected: PASS.

- [ ] **Step 5: Commit** (skip unless asked)

```bash
git add lib/src/xmltv_compact_epg_repository.dart lib/src/xmltv_parser.dart \
  test/xmltv_compact_epg_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(xmltv): pass naiveOffset through compact ingest factories

EOF
)"
```

Open / land the `airo_epg` PR before relying on pub.dev. For Airo Tasks 4–5, a path override is enough.

---

### Task 3: Rust timestamp helper (this repo)

**Files:**
- Modify: `rust/airo_core/src/api/xmltv.rs` (`parse_xmltv_timestamp_epoch_seconds` and its tests)

Native `airo_epg` is still a Dart fallback today. This keeps the future FFI path honest.

- [ ] **Step 1: Write the failing Rust tests**

Next to existing timestamp tests, add:

```rust
    #[test]
    fn naked_stamp_subtracts_naive_offset_tagged_ignores_it() {
        let ist = 5 * 3600 + 30 * 60;
        let naked = parse_xmltv_timestamp_epoch_seconds("20260715090000", ist).unwrap();
        let utc_0330 = parse_xmltv_timestamp_epoch_seconds("20260715033000 +0000", 0).unwrap();
        assert_eq!(naked, utc_0330);

        let tagged = parse_xmltv_timestamp_epoch_seconds("20260715090000 +0000", ist).unwrap();
        let utc_0900 = parse_xmltv_timestamp_epoch_seconds("20260715090000 +0000", 0).unwrap();
        assert_eq!(tagged, utc_0900);
    }
```

- [ ] **Step 2: Run to fail**

Run: `cd rust/airo_core && cargo test naked_stamp_subtracts_naive_offset --lib`

Expected: FAIL (function still has one argument).

- [ ] **Step 3: Implement**

Change the helper to `fn parse_xmltv_timestamp_epoch_seconds(value: &str, naive_offset_seconds: i64) -> Option<i64>`. After computing civil epoch, if the stamp's offset substring is empty and `naive_offset_seconds != 0`, `epoch_seconds -= naive_offset_seconds`. If the stamp has `+`/`-HHMM`, ignore `naive_offset_seconds`.

Update every existing call site in this file to pass `0` (preserving today's tests). Current/next parsers that already parse offsets from the string keep passing `0` unless they also grow a naive-offset argument — for this slice, only the timestamp helper plus unit test are required; do not expand the FFI surface unless a caller already forwards parse options.

- [ ] **Step 4: Re-run**

Run: `cd rust/airo_core && cargo test --lib xmltv`

Expected: PASS.

- [ ] **Step 5: Commit** (skip unless asked)

```bash
git add rust/airo_core/src/api/xmltv.rs
git commit -m "$(cat <<'EOF'
feat(xmltv): apply optional naive offset to unzoned XMLTV stamps

EOF
)"
```

---

### Task 4: Pin `airo_epg` in Airo

**Files:**
- Modify: `packages/platform_epg/pubspec.yaml`

- [ ] **Step 1: Depend on 1.1.0**

If `airo_epg` 1.1.0 is not on pub.dev yet, add a **temporary** path override at the workspace root (or `packages/platform_epg`) pointing at the sibling clone:

```yaml
dependency_overrides:
  airo_epg:
    path: ../../airo_epg
```

Adjust the relative path so it resolves from that pubspec to `/Users/udaychauhan/workspace/airo_epg`. Do not leave a path override in a PR that targets `main` unless the human asked. For a landable PR, set `airo_epg: ^1.1.0` after publish, or a git `ref` the human names.

Then: `cd packages/platform_epg && dart pub get`

- [ ] **Step 2: Analyzer smoke**

Run: `cd packages/platform_epg && dart analyze`

Expected: No issues.

- [ ] **Step 3: Commit** (skip unless asked)

```bash
git add packages/platform_epg/pubspec.yaml packages/platform_epg/pubspec.lock
git commit -m "$(cat <<'EOF'
chore(epg): pin airo_epg with XMLTV naiveOffset

EOF
)"
```

---

### Task 5: Aika Stream refresh passes device offset

**Files:**
- Modify: `packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart`
- Modify: `packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart`

**Interfaces:**
- Consumes: `XmltvCompactEpgRepository.fromXmltvFileNative` `naiveOffset`
- Produces: `naiveOffsetProvider` on `XmltvSourceRefreshService` (default `() => DateTime.now().timeZoneOffset`)

- [ ] **Step 1: Write the failing test**

Append to `xmltv_source_refresh_service_test.dart`. Reuse `_FakeXmltvAdapter` / setUp patterns already in the file. Use a **naked** guide (no `+0000`):

```dart
  test('refresh parses naked stamps with the injected device offset', () async {
    const nakedXmltv = '''
<?xml version="1.0" encoding="UTF-8"?>
<tv>
  <channel id="chan-1"><display-name>Channel 1</display-name></channel>
  <programme start="20260717120000" stop="20260717123000" channel="chan-1">
    <title>Local Noon</title>
  </programme>
</tv>
''';
    final dio = Dio()..httpClientAdapter = _FakeXmltvAdapter(nakedXmltv);
    final offsetService = XmltvSourceRefreshService(
      dio: dio,
      sourceStore: sourceStore,
      repository: repository,
      downloadDirectoryProvider: () async => tempDir,
      naiveOffsetProvider: () => const Duration(hours: 5, minutes: 30),
    );

    await offsetService.refresh('https://example.com/guide.xml');

    final slice = await repository.loadCurrentNext(
      channelIds: ['chan-1'],
      now: DateTime.utc(2026, 7, 17, 6, 40),
    );
    expect(slice.entryForChannel('chan-1')?.current?.title, 'Local Noon');

    final tooEarly = await repository.loadCurrentNext(
      channelIds: ['chan-1'],
      now: DateTime.utc(2026, 7, 17, 12, 10),
    );
    expect(tooEarly.entryForChannel('chan-1')?.current, isNull);
  });
```

12:00 IST naked → 06:30Z. `now` 06:40Z is during the programme; 12:10Z is after 06:30–07:00Z and must not still be "current" (that would mean we still treated 12:00 as UTC).

- [ ] **Step 2: Run to fail**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`

Expected: FAIL (`naiveOffsetProvider` isn't a constructor argument).

- [ ] **Step 3: Implement the seam**

In `xmltv_source_refresh_service.dart`:

```dart
  XmltvSourceRefreshService({
    required this.dio,
    required this.sourceStore,
    required this.repository,
    required this.downloadDirectoryProvider,
    Duration Function()? naiveOffsetProvider,
  }) : naiveOffsetProvider =
           naiveOffsetProvider ?? (() => DateTime.now().timeZoneOffset);

  final Duration Function() naiveOffsetProvider;
```

Pass `naiveOffset: naiveOffsetProvider()` to **both** `fromXmltvFileNative` call sites (the main `refresh` path and the helper around line 405).

- [ ] **Step 4: Re-run**

Run: `cd packages/feature_iptv && flutter test test/iptv/application/xmltv_source_refresh_service_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit** (skip unless asked)

```bash
git add packages/feature_iptv/lib/application/xmltv_source_refresh_service.dart \
  packages/feature_iptv/test/iptv/application/xmltv_source_refresh_service_test.dart
git commit -m "$(cat <<'EOF'
feat(iptv): parse naked XMLTV times in the device zone

EOF
)"
```

---

### Task 6: Analyze + format

- [ ] **Step 1: Format and analyze touched Airo files**

Run:

```bash
cd packages/feature_iptv && dart format lib/application/xmltv_source_refresh_service.dart \
  test/iptv/application/xmltv_source_refresh_service_test.dart \
  && dart analyze lib/application/xmltv_source_refresh_service.dart
cd ../../packages/platform_epg && dart analyze
```

In the airo_epg clone: `dart format lib test && dart analyze`

Expected: No issues.

- [ ] **Step 2: Confirm no Settings chrome**

Grep `packages/feature_iptv/lib` for `naiveOffset` / `timezone offset` / `Sleep timer`-style new copy. The only production hit should be `xmltv_source_refresh_service.dart`. Do not add UI if something leaked.

- [ ] **Step 3: Commit** (skip unless asked)

---

## Self-review (plan vs spec)

| Spec | Task |
| --- | --- |
| UTC store, `.toLocal()` display unchanged | 5 (ingest only) |
| Naked + device zone | 1, 2, 5 |
| Tagged ignores device offset | 1, 2 |
| No Settings row | 5, 6 grep |
| `DateTime.now().timeZoneOffset`, no new package | 5 |
| DST = ingest-time offset | 5 default provider |
| Next refresh realigns (no TZ listener) | 5 (existing refresh) |
| `naiveOffset == null` → UTC | 1 |
| airo_epg ICAST | 1, 2, 4 |
| Rust same rule | 3 |
| Refresh tests with injected clock | 5 |
| No CV-016 / live peek / regex rewrite | all |
