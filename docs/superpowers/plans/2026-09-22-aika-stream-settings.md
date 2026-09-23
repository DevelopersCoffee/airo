<!-- /autoplan restore point: "/Users/udaychauhan/.gstack/projects/DevelopersCoffee-airo/main-autoplan-restore-20260922-190211.md" -->
# Aika Stream Settings Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give Aika Stream a living-room Settings home for preferences the app already persists (text size, captions, country, grid density, phone privacy) without building a new settings platform.

**Architecture:** Keep the shared `iptvSettingsSections` manifest in `packages/feature_iptv_core` as the SSOT. Add `IptvSettingsSectionId.accessibility`. TV `TvSettingsScreen` and phone `SettingsHubScreen` both read visibility from that list. New widgets live in `packages/feature_iptv` (font, captions, density, country already do). App-layer TV privacy stays in `app/lib/features/settings` because it uses `streamingTelemetryConsentProvider` and `deleteAikaStreamLocalData`.

**Tech Stack:** Flutter, Riverpod, existing `SharedPreferences` providers. No new packages.

**Design:** `docs/designs/aika-stream-settings.md`

**Status:** APPROVED 2026-09-23 via /autoplan Final Gate option A (accept all recommendations). Implementer SSOT: locked table + Tasks 1–6 as Eng-amended. Native Eng: [flutter-architect](eecb17c4-c49d-4305-a4a0-0dd6bb36a43f). Codex unavailable all phases (`gpt-6-astra` ChatGPT 400).

---

## Implementation plan

### Objective

Close the gap between stored Aika Stream preferences and the Settings UI. Slice 1 only: wire existing providers. Later slices (audio language store, EPG offset, resume-on-launch, sleep timer, per-source headers) stay listed as follow-ups, not this packet.

### Locked decisions

| Topic | Decision |
| --- | --- |
| Packet | Slice 1: Accessibility (font + captions) + country on TV + privacy on phone Aika Stream. Grid density stays phone Playback only |
| Manifest | Add `accessibility` immediately after `theme`; move `country` before `sources` so TV-visible order is Theme → Accessibility → Playback → Country → Sources → Privacy. Widen `country` only. Keep `privacy` TV-only in the manifest; compact hub special-cases Privacy |
| Font | Reuse `tvFontModeProvider`. Apply `.scale` to live `ChannelLibraryGrid` tile names, not only `TvChannelGrid` |
| Captions | Reuse `captionPreferenceProvider`. Settings is Off/On only. Player still applies only when `enabled && languageCode != null`. Copy must not claim stream default |
| Country | Reuse `CountrySettingsTile({bool forTv = false})`. TV: `TvFocusable` + existing `showTvLongListPicker`. Phone keeps `showFilterOptionDialog`. Empty list stays focusable; onSelect no-op. Do not invent a third picker |
| Privacy on phone | `TvPrivacySection({bool showTelemetry = true, bool deleteFirst = false})`. Compact hub: `showTelemetry: false, deleteFirst: true`. No `PlatformMediaLogger` probe (no `isBootstrapped`). Confirm autofocus Cancel |
| Density | Phone Playback / explorer only. Do not mount on 10-foot `TvPlaybackSection` (`phoneGridColumns` is ignored above 600px) |
| Audio ducking | Stay `ShellId.mobile` only. Compact Aika Stream hub currently shows the tile — wrap it |
| PiP / haptics | Stay phone Playback. TV Playback stays aspect ratio only |
| Parental / ads / decoder | Out of this packet |

### What already exists

- TV rail: Theme, Playback (aspect), Sources, Privacy, About (`app/lib/features/settings/presentation/tv/tv_settings_screen.dart`).
- Phone hub: Appearance, Audio ducking, Playback, Country, Playlist, EPG (`app/lib/features/settings/presentation/screens/settings_hub_screen.dart`).
- `tvFontModeProvider` applied in `tv_channel_grid.dart` (multiplies fontSize) and already in live `ChannelLibraryGrid` (`_ChannelTile` wraps each card in MediaQuery textScaler `baseScale * fontMode.scale`, commit `4120f32f`). Do not add a second scale multiply.
- `captionPreferenceProvider` applied in `video_player_widget.dart`, never in Settings.
- `channelGridDensityProvider` + `ChannelGridDensitySection` on phone Playback and explorer dialog.
- `CountrySettingsTile` phone-only.
- Privacy (telemetry + delete local data) TV-only.
- Haptic strength picker on phone Playback (`aikaHapticStrengthProvider`).
- Explorer dialog: control-row visibility, playlist/guide shortcuts, density, backup/restore.

### NOT in scope

- CV-013 household profiles / PIN / category lock.
- Ads personalization or AdMob opt-out.
- Super-app Smart Audio on TV.
- Surf mode (no implementation).
- EPG timezone offset, resume last channel, sleep timer on TV, User-Agent UI, hardware decoder, buffer size, external player.
- Cloud-synced settings.
- Moving backup/restore onto the TV rail (TV `file_picker` is stubbed; keep it on the explorer dialog until a TV-safe export path exists).
- Changing ad policy, Play Data Safety copy, or `aika-stream-release.yml`.

### File structure

```
packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart   [modify: add accessibility; widen country; privacy stays TV]
packages/feature_iptv/lib/presentation/screens/settings/
  accessibility_settings_section.dart                            [new: font + captions]
packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart [modify: apply tvFontMode]
packages/feature_iptv/test/iptv/domain/iptv_settings_manifest_test.dart      [modify]
packages/feature_iptv/test/iptv/presentation/screens/settings/
  accessibility_settings_section_test.dart                       [new]
app/lib/features/settings/presentation/tv/tv_settings_screen.dart [modify: accessibility + country cases]
app/lib/features/settings/presentation/screens/settings_hub_screen.dart [modify: accessibility + privacy]
app/test/features/settings/presentation/tv/tv_settings_screen_test.dart [modify]
app/test/features/settings/presentation/screens/settings_hub_screen_test.dart [modify]
```

### Task 1: Manifest — Accessibility section + shell visibility

**Files:**
- Modify: `packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart`
- Modify: `packages/feature_iptv/test/iptv/domain/iptv_settings_manifest_test.dart`

- [ ] Add `IptvSettingsSectionId.accessibility` with label `Accessibility`, icon `Icons.accessibility_new`, visible on `{ShellId.mobile, ShellId.tv}`. Insert immediately after `theme`. Do not add a redundant TV label override. Update the manifest file header so it no longer says TV omits country.
- [ ] Place `country` before `sources` in `iptvSettingsSections` so TV-visible rail order is Theme → Accessibility → Playback → Country → Sources → Privacy (About is the extra Airo Apps / info stop).
- [ ] Set `country.visibleForShells` to `{ShellId.mobile, ShellId.tv}`.
- [ ] Leave `privacy.visibleForShells` as `{ShellId.tv}`. The phone hub does not iterate the manifest; compact Aika Stream special-cases Privacy in Task 5. Super-app must not gain a Privacy tile because of a widened set.
- [ ] Update manifest tests: TV visible set includes accessibility, country, privacy; mobile includes accessibility, not privacy.
- [ ] Exhaustiveness: every `switch` on `IptvSettingsSectionId` in app/feature_iptv must compile. Fix `TvSettingsScreen._buildDetail` as part of Task 4.

### Task 2: Accessibility section widget (font + captions)

**Files:**
- Create: `packages/feature_iptv/lib/presentation/screens/settings/accessibility_settings_section.dart`
- Create: `packages/feature_iptv/test/iptv/presentation/screens/settings/accessibility_settings_section_test.dart`
- Export next to `CountrySettingsTile` in `packages/feature_iptv/lib/feature_iptv.dart`.

Constructor: `AccessibilitySettingsSection({required bool forTv})`. Mirror Playback: TV detail is a `ListView` of `TvFocusable` rows like `TvPlaybackSection` (the rail already hosts one scroller). Phone is a `ListView` (not a Column — captions copy overflows small phones) with a Switch for captions. Pushed hub route uses AppBar title `Accessibility`. Do not invent a dual anonymous layout.

The widget contains:

1. Text size: three `TvFocusable` options mapped to `TvFontMode.standard|large|extraLarge`, labels "Standard", "Large", "Extra large". Selecting calls `tvFontModeProvider.notifier.setTvFontMode`. Font copy: "Text size applies to channel names in the library."
2. Captions: Off/On only via `setCaptionsEnabled`. No language picker. TV chrome: two `TvFocusable` rows with a check on the selected row — not a Switch. Phone may use a Switch. Copy (exact): "On reapplies the last language you picked in the player. If you have not picked one yet, captions stay off until you do." Do not write "stream default." Status under the control: if `languageCode == null`, "No language saved — pick one in the player."; else "Saved language: {code}." Do not change `_applyCaptionPreferenceIfNeeded`. Preferred caption/audio language is CV-016.
3. Use `TvFocusable` for every TV option including captions Off/On.

Tests:

- Selecting Large writes `tv_font_mode` = `large` and the grid scale is `1.25`.
- Toggling captions writes `caption_preference_enabled`.
- TV focusables have semantic labels.

### Task 3: Apply text size to live Library grid

**Files:**
- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart`
- Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart`
- Do not modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart` (no density on 10-foot Playback)

- [ ] Promote `ChannelLibraryGrid` to `ConsumerStatefulWidget` and watch `tvFontModeProvider` once. Keep a single MediaQuery `textScaler: TextScaler.linear(baseScale * fontMode.scale)` around every card branch (MediaCard, compact, horizontal). Remove the per-tile Consumer + ProviderScope try/catch. Do **not** also multiply `_CompactGridMediaCard` / `_HorizontalMediaCard` `fontSize` by `TvFontMode.scale` (Flutter already applies textScaler; Extra large would become 2.25×). Do not add `fontSize` to `MediaCard` / `AiroRailCard`. Do not rewrite `core_ui` `ThemeData`. Do not scale Settings chrome.
- [ ] When `fontMode.scale > 1`, grow TV `rowExtent` above `_cardHeight` (169) with the scaled text block, or drop subtitle on the MediaCard path. Phone 5-up already drops subtitle via `compactGridShowSubtitle`. Update the in-file `_cardHeight` comment.
- [ ] Widget tests: Extra large vs Standard on a TV-width viewport (≥600) with `expect(tester.takeException(), isNull)`; Extra large name scale ratio close to 1.5 not 2.25; assert MediaCard path via laid-out height or `RenderParagraph.textScaler`, not `Text.style.fontSize`. Wrap every existing `channel_library_grid_test.dart` pump in `ProviderScope` + `sharedPreferencesProvider`.
- [ ] Assert `TvPlaybackSection` does **not** contain `ChannelGridDensitySection` (`findsNothing` in `tv_playback_section_test.dart`). Phone Playback keeps density.

### Task 4: TV rail detail routing

**Files:**
- Modify: `app/lib/features/settings/presentation/tv/tv_settings_screen.dart`
- Modify: `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart`

- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection(forTv: true)`; `country` → `CountrySettingsTile(forTv: true)` (`TvFocusable` + existing `showTvLongListPicker`; when `!canPickCountry`, keep the row focusable and do not open a picker). Use `labelFor`/`iconFor` for `ShellId.tv` when `forTv`. Invert `tv_settings_screen_test` Accessibility `findsNothing`. Remove those ids from the "never selected" shrink list.
- [ ] Tests: rail order Theme, Accessibility, Playback, Country, Sources, Privacy, then About. Selecting Accessibility shows font options and captions Off/On rows; selecting Country shows the country tile. Existing theme/playback/sources/privacy tests stay green.

### Task 5: Phone hub tiles

**Files:**
- Modify: `app/lib/features/settings/presentation/screens/settings_hub_screen.dart`
- Modify: `app/test/features/settings/presentation/screens/settings_hub_screen_test.dart`

- [ ] Add Accessibility tile immediately after Appearance (manifest labels) pushing a `Scaffold` with AppBar title `Accessibility` that hosts `AccessibilitySettingsSection(forTv: false)` in a `ListView`. Comment: compact `ShellId.tv` hub is phone layout + opt-in Privacy; do not iterate the TV-visible manifest set.
- [ ] Add Privacy tile only when `shellId == ShellId.tv` (compact Aika Stream hub). Super-app `ShellId.mobile` does not get it. Host `TvPrivacySection(showTelemetry: false, deleteFirst: true)`. Keep existing delete failure/success dialogs. Confirm autofocus **Cancel** on both shells (TV today autofocuses Delete).
- [ ] Wrap the existing Audio Settings `ListTile` in `shellId == ShellId.mobile`. Compact Aika Stream hub currently shows it; hide it on `ShellId.tv`.
- [ ] Tests: super-app hub has Accessibility, no Privacy; Aika Stream compact hub has Accessibility + Privacy, no Audio Settings; tapping Privacy can reach "Delete local data" with Cancel focused on the confirm dialog.

### Task 6: Analyzer + focused tests

Copy-paste hello world (implementer TTHW, target < 5 min after codegen):

```
cd packages/feature_iptv && flutter test \
  test/iptv/domain/iptv_settings_manifest_test.dart \
  test/iptv/presentation/screens/settings/accessibility_settings_section_test.dart \
  test/iptv/presentation/tv_ux/channel_library_grid_test.dart \
  test/iptv/presentation/tv/settings/tv_playback_section_test.dart
```

Override recipe (put in the Accessibility widget test): `ProviderScope(overrides: [sharedPreferencesProvider, tvFontModeProvider, captionPreferenceProvider])` with `languageCode: 'eng'` when proving captions On + saved language. Match `tv_font_mode_provider_test.dart`.

- [ ] `dart analyze` on `packages/feature_iptv_core`, `packages/feature_iptv`, `app` (tv settings files).
- [ ] `flutter test` the files named above plus `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart`, `app/test/features/settings/presentation/screens/settings_hub_screen_test.dart`, and `app/test/features/settings/presentation/tv/tv_privacy_section_test.dart` (`showTelemetry: false`, `deleteFirst: true`, Cancel focused). Add a focused captions apply-gate test: enabled + null language does not select; enabled + `eng` would. Do not run the full workspace matrix.

### Follow-ups (not this PR)

Record in `TODOS.md` after merge, not as incomplete checkboxes here:

1. Preferred audio language store (CV-016) once player track lists are stable.
2. EPG timezone offset for XMLTV that is not in the device zone.
3. Resume last live channel on TV launch.
4. Sleep timer on the TV binary (`sleepTimerProvider` is phone `app_shell` today).
5. Per-source HTTP User-Agent / Referer editor (`ChannelHeaders` already on `IPTVChannel`).
6. TV-safe backup path (replace stubbed `file_picker`).
7. Caption appearance (size/color) beyond on/off.
8. Revisit ads consent if Play policy requires a toggle.

### Test plan (Slice 1)

| Path | Proof |
| --- | --- |
| Font Large on TV Settings | Channel names in live Library enlarge; restart keeps Large; Settings rail labels unchanged |
| Captions On + saved language | Next stream with a matching subtitle track enables captions without opening the player menu first |
| Captions On + no language | Preference stores enabled; player stays without captions until a language is picked in-player |
| Country on TV | Filter applies to browse; matches phone behavior |
| Density | Unchanged on phone Playback; absent from TV Playback |
| Privacy on phone hub | Delete local data first; confirm focuses Cancel; wipes sources/favorites like TV |
| Audio ducking | Absent from Aika Stream TV rail and `ShellId.tv` compact hub |
| Fire TV D-pad | Every new option is `TvFocusable`; captions are Off/On rows; Back returns to rail |

### Risk

- `CountrySettingsTile` uses mobile `ListTile` / `showFilterOptionDialog`. TV `forTv: true` uses existing `showTvLongListPicker` (browse already does; FilterOptionDialog does not scale to a full country list). Empty country: focusable no-op.
- Privacy: do not probe `PlatformMediaLogger` (no `isBootstrapped`; default is already `AiroNoOpAnalyticsService`). Compact hub passes `showTelemetry: false` and must not autofocus a missing consent row. Prefs notifiers keep swallowing save failures this packet; do not rewrite them.
- Library already applies `tvFontMode` via per-tile MediaQuery. Slice 1 must collapse to one grid-level seam and grow TV rowExtent when scale > 1. If Settings chrome does not scale, that is acceptable; do not rewrite `core_ui` text theme.


<!-- autoplan-accepted:ceo -->
- Slice 1 wires existing providers through `iptvSettingsSections`. Success: a Fire TV user can enlarge text and turn captions on from Settings without starting a stream. Verify: font Large persists after restart and scales channel grid; captions On enables matching subtitle tracks on the next stream.
- Captions Settings is on/off only. Copy: "On uses the stream default; pick a language from the player." No language picker in this packet. Verify: widget test toggles `caption_preference_enabled`; no language list in Accessibility.
- Font copy: "Text size applies to the channel grid." Do not rewrite `core_ui` text theme. Verify: Settings chrome size unchanged; Library/Watch channel names scale.
- Privacy tile only on Aika Stream shells (`ShellId.tv` compact + Aika Stream phone). Super-app `ShellId.mobile` does not get it. Destructive copy names Aika Stream local data. On phone, lead with Delete local data; hide or disable telemetry share when `PlatformMediaLogger` is absent. Verify: super-app hub test has no Privacy/Delete local data; Aika Stream compact hub does.
- Country is its own TV rail section (not buried in Sources). Density mounts in TV Playback with D-pad-safe controls. Verify: Fire TV can change both and Back returns to rail.
- Parental/PIN, ads, Smart Audio on TV, PiP/haptics on TV, surf mode, cloud sync, TV backup, release-yml stay out of this packet.
- After merge, two P2 follow-ups with owners: (a) preferred audio/caption language once player tracks are stable; (b) resume last channel + sleep timer on the TV binary. EPG offset, UA editor, TV backup, caption appearance, ads consent stay P3.
<!-- /autoplan-accepted:ceo -->

<!-- autoplan-accepted:design -->
- Apply `tvFontModeProvider.scale` to live `ChannelLibraryGrid` tile names (`MediaCard`, `_CompactGridMediaCard`, `_HorizontalMediaCard`). Do not claim Watch chrome scales. Do not rewrite `core_ui` text theme.
  Verify: Large then restart; Library names larger; Settings rail labels unchanged; `tv_channel_grid.dart` path still scales.
- Captions Settings is Off/On only. TV: two `TvFocusable` check rows, not a Switch. Copy: "On reapplies the last language you picked in the player. If you have not picked one yet, captions stay off until you do." Status: `languageCode == null` → "No language saved — pick one in the player." Else "Saved language: {code}." Do not write "stream default." Do not change `_applyCaptionPreferenceIfNeeded` (still requires enabled + languageCode).
  Verify: widget test On writes `caption_preference_enabled`; no language list; copy string present; player still no-ops when languageCode is null.
- Do not mount `ChannelGridDensitySection` on 10-foot `TvPlaybackSection`. Density remains phone Playback + explorer (`phoneGridColumns` only below 600px).
  Verify: TV Playback test has no density radios; phone Playback still has them.
- TV rail order (manifest list, TV-visible): Theme → Accessibility → Playback → Country → Sources → Privacy → About.
  Verify: widget test rail order; Back from each new detail returns to rail.
- Hide Audio ducking unless `shellId == ShellId.mobile`. Compact Aika Stream hub currently shows it; wrap that tile.
  Verify: `SettingsHubScreen(shellId: ShellId.tv)` has no Audio Settings tile.
- Phone Privacy: Delete local data first; hide telemetry when logger absent. Confirm dialog autofocus Cancel (TV today autofocuses Delete — change both shells).
  Verify: phone Aika Stream hub Privacy; super-app negative test; confirm initial focus is Cancel.
<!-- /autoplan-accepted:design -->

<!-- autoplan-accepted:dx -->
- `AccessibilitySettingsSection({required bool forTv})`. TV: `ListView` of `TvFocusable` rows like `TvPlaybackSection`. Phone: `Column`/`ListView` + captions Switch. Export next to `CountrySettingsTile`.
  Verify: `forTv: true` has no Material Switch; phone test uses Switch.
- Library text size seam: wrap the `MediaCard` branch in `MediaQuery` `textScaler: TextScaler.linear(scale)`. Multiply fontSize only on local `_CompactGridMediaCard` / `_HorizontalMediaCard`. Do not add `fontSize` to `MediaCard`.
  Verify: Extra large enlarges Library names; no `core_ui` MediaCard signature change.
- `CountrySettingsTile({bool forTv = false})`. TV: `TvFocusable` + existing `showFilterOptionDialog`. Empty list stays focusable with existing subtitle.
  Verify: Fire TV can open country picker; no second picker widget.
- Keep `privacy.visibleForShells` as `{ShellId.tv}`. Compact hub (`shellId == ShellId.tv`) special-cases `TvPrivacySection(showTelemetry: false, deleteFirst: true)`. Super-app hub does not.
  Verify: manifest mobile set has no privacy; compact hub has Delete local data; super-app does not.
- Confirm dialog autofocus Cancel on both shells. Do not probe `PlatformMediaLogger`. Do not rewrite prefs notifiers.
  Verify: confirm initial focus Cancel; no `isBootstrapped` call.
- Copy-paste Task 6 `flutter test` recipe plus `ProviderScope` override with `languageCode: 'eng'` for captions On + language.
  Verify: recipe present in plan; Accessibility test file lives under `test/iptv/presentation/`.
<!-- /autoplan-accepted:dx -->

<!-- autoplan-accepted:eng -->
- Library scale: `_ChannelTile` already wraps cards in `MediaQuery` `textScaler: TextScaler.linear(baseScale * fontMode.scale)` (`channel_library_grid.dart` ~975-989). Promote `ChannelLibraryGrid` to `ConsumerStatefulWidget`, watch `tvFontModeProvider` once, one MediaQuery seam for every card branch. Do not multiply local `_CompactGridMediaCard` / `_HorizontalMediaCard` `fontSize` while those cards sit under that MediaQuery. Remove per-tile Consumer + try/catch.
  Verify: Extra large name ratio ~1.5 not 2.25; no MediaCard signature change; existing Library pumps use ProviderScope + sharedPreferencesProvider.
- TV Library overflow: `_cardHeight` is fixed 169. When `fontMode.scale > 1`, grow TV `rowExtent` with the scaled text block (or drop subtitle on the MediaCard path). Phone 5-up already drops subtitle via `compactGridShowSubtitle`.
  Verify: viewport width ≥600, Extra large vs Standard, `tester.takeException() == null`.
- TV country: `forTv: true` calls existing `showTvLongListPicker`. Phone keeps `showFilterOptionDialog`. No third picker. When `!canPickCountry`, row stays focusable; onSelect no-op. Use `labelFor`/`iconFor` for `ShellId.tv` when `forTv`.
  Verify: empty-country row present and focusable; picker does not open.
- `TvPrivacySection({bool showTelemetry = true, bool deleteFirst = false})`. If `!showTelemetry`, do not mount consent rows and do not autofocus a missing widget. Confirm: `TvFocusable(autofocus: true)` on Cancel only, both shells. Extend `tv_privacy_section_test.dart`. Do not call `PlatformMediaLogger` / `isBootstrapped`.
- Hub stays hardcoded. Comment: compact `ShellId.tv` hub is phone layout + opt-in Privacy; do not iterate TV-visible `iptvSettingsSections`. Accessibility push: AppBar title `Accessibility`; body `ListView`.
- Captions apply gate: keep `_applyCaptionPreferenceIfNeeded` unchanged. Add a focused test: enabled + `languageCode == null` does not select a track; enabled + `eng` would. Invert `tv_settings_screen_test` Accessibility `findsNothing`. Density: `find.byType(ChannelGridDensitySection), findsNothing` on TV Playback.
- Implementer SSOT is locked table + Tasks 1-6 as Eng-amended. CEO accepted recap ("stream default"; density on TV Playback) stays byte-for-byte but is superseded. DX TV `showFilterOptionDialog` is superseded by `showTvLongListPicker`.
<!-- /autoplan-accepted:eng -->
## Review record

Autoplan intake: 2026-09-22. Base branch: `main`. SOURCE/ACTIVE plan: this file. Spec: `docs/designs/aika-stream-settings.md`. UI scope: yes. DX scope: yes (term matcher). Codex: unavailable (`gpt-6-astra` not supported on ChatGPT account). Native CEO: in-host + [product-manager](3e1a28ed-2e23-4f16-8a79-4d529c8c49a4). Tag: `[subagent-only]`. Mode: SELECTIVE_EXPANSION (autoplan override).

<!-- autoplan-baseline-edits:ceo {"sourceSha256":"0018c709179776847433dea389215c303c2798ea78e593c51eaf1f35f7c01a29","replacements":[{"oldText":"2. Captions: on/off via `captionPreferenceProvider.notifier.setCaptionsEnabled`. Language: show current `languageCode` or \"Stream default\"; do not invent a world language catalog. If the player already has a language picker helper, reuse it. If not, persist enabled-only in this packet and leave language to the in-player track list (CV-016). Prefer enabled-only if no existing language picker widget exists in settings.","newText":"2. Captions: on/off only via `captionPreferenceProvider.notifier.setCaptionsEnabled`. Copy: \"On uses the stream default; pick a language from the player.\" Do not show a language picker in this packet. Font copy: \"Text size applies to the channel grid.\" Preferred caption/audio language is CV-016."},{"oldText":"- [ ] Add Privacy tile for every hub that already shows IPTV sections, including `ShellId.tv` compact. Host `TvPrivacySection` or a shared extract. Delete-local-data must work on phone.","newText":"- [ ] Add Privacy tile only on Aika Stream shells (`ShellId.tv` compact and the Aika Stream phone hub). Super-app `ShellId.mobile` does not get this tile. Host `TvPrivacySection` or a shared extract. Delete-local-data must work on phone. On phone, lead with Delete local data; hide or disable the telemetry share toggle when `PlatformMediaLogger` is not bootstrapped."}]} -->

<!-- autoplan-accepted:ceo -->
- Slice 1 wires existing providers through `iptvSettingsSections`. Success: a Fire TV user can enlarge text and turn captions on from Settings without starting a stream. Verify: font Large persists after restart and scales channel grid; captions On enables matching subtitle tracks on the next stream.
- Captions Settings is on/off only. Copy: "On uses the stream default; pick a language from the player." No language picker in this packet. Verify: widget test toggles `caption_preference_enabled`; no language list in Accessibility.
- Font copy: "Text size applies to the channel grid." Do not rewrite `core_ui` text theme. Verify: Settings chrome size unchanged; Library/Watch channel names scale.
- Privacy tile only on Aika Stream shells (`ShellId.tv` compact + Aika Stream phone). Super-app `ShellId.mobile` does not get it. Destructive copy names Aika Stream local data. On phone, lead with Delete local data; hide or disable telemetry share when `PlatformMediaLogger` is absent. Verify: super-app hub test has no Privacy/Delete local data; Aika Stream compact hub does.
- Country is its own TV rail section (not buried in Sources). Density mounts in TV Playback with D-pad-safe controls. Verify: Fire TV can change both and Back returns to rail.
- Parental/PIN, ads, Smart Audio on TV, PiP/haptics on TV, surf mode, cloud sync, TV backup, release-yml stay out of this packet.
- After merge, two P2 follow-ups with owners: (a) preferred audio/caption language once player tracks are stable; (b) resume last channel + sleep timer on the TV binary. EPG offset, UA editor, TV backup, caption appearance, ads consent stay P3.
<!-- /autoplan-accepted:ceo -->

### 0A Premise challenge

| Premise | Verdict |
| --- | --- |
| Sofa users look in Settings for text size and captions | Valid. In-player menus exist but persist prefs with no home. Real pain. |
| Enabling captions from Settings without a language picker is enough | Accepted with honest copy. Language is CV-016, not this packet. Queued as taste if users bounce. |
| Grid-only font scale is acceptable | Stated. Six-month risk: Accessibility looks unfinished. Copy must say it applies to the channel grid. |
| Phone Privacy is needed because Android app-info is the only wipe | Valid for Aika Stream. Invalid as a super-app hub tile. Task 5 restated. |
| Country on TV is a Settings-rail problem | Valid TV pattern. Not a 10x problem; cheap reuse. |
| Wiring existing providers is the right next packet | Valid. The 10x living-room product is resume + sleep + UA. Those stay follow-ups. |

Doing nothing: Fire TV still cannot change the two prefs that already affect the 10-foot UI.

Wrong framing: "build a complete IPTV settings product in this PR." That pulls PIN, decoder, UA into a wiring packet.

### 0B Existing code leverage

| Sub-problem | Existing code | This plan |
| --- | --- | --- |
| Text size | `tvFontModeProvider` + `tv_channel_grid.dart` | New Settings home |
| Captions persist | `captionPreferenceProvider` + player | On/off Settings home |
| Country filter | `CountrySettingsTile` + `channelFiltersProvider` | TV rail |
| Grid density | `ChannelGridDensitySection` | TV Playback |
| Delete local data | `deleteAikaStreamLocalData` + `TvPrivacySection` | Aika Stream phone only |
| Section list | `iptvSettingsSections` | Add `accessibility`; widen visibility |
| Audio ducking | `AudioSettingsScreen` | Leave super-app only |
| Haptics / PiP | Phone Playback | Leave phone |

No rebuild of stores.

### 0C Dream state

```
CURRENT                         THIS PLAN                         12-MONTH
TV rail: theme, aspect,         + Accessibility (font+CC on/off)  Living-room player:
sources, privacy, about         + country rail + density          resume, sleep, UA,
Phone: ducking, PiP, haptics,   Phone Aika Stream: privacy wipe   EPG offset, caption
country, playlist, EPG          Honest copy, no super-app wipe    language, PIN optional
Prefs persist without a home    Sofa can change font + captions   Settings chrome scales
```

Delta: catalog hygiene, not the 12-month TV player. Correct next step if follow-ups stay sequenced.

### 0C-bis Implementation alternatives

APPROACH A: Surface existing providers through the shared manifest (this plan)
  Effort: S  Risk: Low  Completeness: 8/10
  Pros: reuses stores; one Accessibility rail; Fire TV can change font/captions
  Cons: Accessibility name overclaims; Task 5 originally too wide
  Reuses: `tvFontModeProvider`, `captionPreferenceProvider`, `iptvSettingsSections`

APPROACH B: Font + captions only under Playback, no new rail
  Effort: S  Risk: Low  Completeness: 6/10
  Pros: matches phone Playback grouping; fewer rail stops
  Cons: sofa users hunting Accessibility miss it; CV-008 named a mode

APPROACH C: First-run sofa prompt instead of Settings tiles
  Effort: M  Risk: Med  Completeness: 4/10
  Pros: reaches users who never open Settings
  Cons: new onboarding; does not replace a Settings home

Recommendation: A because P1 completeness + P5 explicit rail + existing CV-008 naming. Auto-decided.

### 0F Mode

SELECTIVE_EXPANSION (autoplan default for feature enhancement). Cherry-picks auto-decided below.

### 0D Selective expansions (auto-decided)

| Proposal | Effort | Decision | Principle |
| --- | --- | --- | --- |
| Privacy on super-app hub | S | Skip | P4/P5 — wrong product identity |
| Caption language picker now | M | Defer CV-016 | P3 — no picker widget |
| Settings chrome font scale | L | Defer | P3 — `core_ui` rewrite |
| Resume + sleep in this PR | L | Defer P2 | P3 — new stores, not wiring |
| Explorer toggles on TV rail | S | Skip | P5 — Pixel compact chrome |
| First-run captions prompt | M | Skip | P3 — not Settings home |

Delight scan (not added): caption size/color, EPG offset, UA editor, TV backup, ads consent, surf mode. All remain follow-ups.

### 0E Temporal interrogation

```
HOUR 1: Manifest exhaustiveness; every switch on IptvSettingsSectionId compiles
HOUR 2-3: TvFocusable around CountrySettingsTile dialogs; density RadioListTile on D-pad
HOUR 4-5: Super-app hub must not gain Delete local data; telemetry toggle absent if no logger
HOUR 6+: Fire TV: Back to rail; captions On with no matching track must not error
```

### Dual voices

CODEX SAYS (CEO): unavailable. `codex exec` HTTP 400: `gpt-6-astra` is not supported with a ChatGPT account. Fix: `GSTACK_CODEX_MODEL=<supported-model>`. Outside coverage missing.

Claude SUBAGENT (CEO — [product-manager](3e1a28ed-2e23-4f16-8a79-4d529c8c49a4)): Approve Slice 1 with conditions. Privacy Aika Stream only. Captions on/off with honest copy. Sequence resume/sleep/audio language. Do not sell as a complete living-room settings product.

CEO DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Codex  Consensus
  ──────────────────────────────────── ─────── ─────── ─────────
  1. Premises valid?                   Y       N/A    N/A
  2. Right problem to solve?           Y       N/A    N/A
  3. Scope calibration correct?        Y*      N/A    N/A
  4. Alternatives sufficiently explored? Y     N/A    N/A
  5. Competitive/market risks covered? Y       N/A    N/A
  6. 6-month trajectory sound?         Y*      N/A    N/A
═══════════════════════════════════════════════════════════════
* with Task 5 restatement and sequenced P2 follow-ups.
CONFIRMED requires completed subagent + outside. Outside unavailable: all Consensus N/A.
Tag: `[subagent-only]`.

### Section 1 Architecture

```
iptvSettingsSections (feature_iptv_core)
        │
        ├── TvSettingsScreen (app, TV rail)
        │     theme | playback+density | sources | accessibility | country | privacy | about
        └── SettingsHubScreen (app, phone list)
              Aika Stream compact: +accessibility +privacy (no ducking)
              Super-app mobile: ducking, no privacy wipe
feature_iptv widgets: AccessibilitySettingsSection, CountrySettingsTile, ChannelGridDensitySection
providers: tvFontMode / captionPreference / channelFilters / channelGridDensity / deleteAikaStreamLocalData
```

Nil/empty: no channels → country picker disabled (already). Captions On with no tracks → stay On, player no-ops (must not throw). Privacy delete failure → existing dialog. No new coupling beyond app composing feature_iptv widgets (existing pattern). Rollback: git revert; prefs keys already exist.

No issues beyond accepted Task 5 restatement. Examined rail vs hub split, provider ownership, super-app vs Aika Stream identity.

### Section 2 Error & Rescue Registry

| CODEPATH | WHAT CAN GO WRONG | EXCEPTION | RESCUED | USER SEES |
| --- | --- | --- | --- | --- |
| `setTvFontMode` persist | prefs write fail | caught in notifier | Y (keep default) | last value; no toast today |
| `setCaptionsEnabled` persist | prefs write fail | same | Y | same |
| Country picker with empty dimensions | no countries | disabled tile | Y | "Load channels first…" |
| `deleteAikaStreamLocalData` | store error | catch in `TvPrivacySection` | Y | "Could not delete…" dialog |
| Captions On, no subtitle tracks | no matching track | none | Y (player) | captions stay Off visually until a track exists |
| Density RadioListTile on Fire TV | not D-pad selectable | UX | N ← GAP | user cannot change density |

GAP: density D-pad. Accepted: wrap in `TvFocusable` or TV option list (Task 3 already). Verify on Fire TV.

Prefs notifiers swallow errors (existing pattern). Slice 1 does not add toasts; do not rewrite notifiers in this packet (P3).

### Section 3 Security

Delete local data is destructive local wipe, no account. Threat: user hits Delete on the wrong shell (super-app). Mitigated by accepted Aika Stream-only tile. No new network, secrets, or packages. Telemetry toggle must not claim sharing if logger is absent (trust). Likelihood Med / impact High if mis-targeted; after restatement Low/Med.

### Section 4 Data / interaction edges

Font: double-select same mode is idempotent. Captions: toggle mid-stream applies on next play (existing player). Country: clear filter vs set. Privacy: confirm dialog, cancel, failure dialog (existing). Density: mid-browse rebuild. Back from TV detail to rail. Empty country list. Unhandled previously: super-app wipe — now out of scope.

### Section 5 Quality

Reuse widgets. Do not fork country picker. Accessibility widget in `feature_iptv` (like Playback). App only routes. TV `RadioListTile` under-engineering called out in Task 3.

### Section 6 Tests

New UX: Accessibility rail, country rail, density on TV Playback, phone Accessibility, Aika Stream Privacy.
Tests in plan: manifest visibility, font persist, captions persist, hub tiles, Fire TV D-pad.
Missing until accepted: super-app hub has **no** Privacy tile (negative test). Add to Task 5 tests.

### Section 7 Perf

Font scale is a multiplier on existing text. Density rebuilds grid. No new network or isolates. Nothing flagged.

### Section 8 Observability

Prefs writes already silent. Delete local data has user dialogs. No new metrics required for Slice 1. Privacy telemetry remains existing consent path.

### Section 9 Deploy

No migration. Prefs keys already in the wild. Revert the PR. Qualify font + captions on Fire TV before default messaging. No feature flag (P5).

### Section 10 Trajectory

Reversibility 4/5. Debt: Accessibility name vs grid-only scale. Next packets: CV-016 language, then resume+sleep. Do not let TODOS become a graveyard.

### Section 11 Design (UI)

First: Accessibility (font, captions). Second: Playback density. Third: Country. Privacy last (destructive). Empty: country disabled. Error: delete-failed dialog. Loading: country "Loading countries…". Recommend `/plan-design-review` in Phase 2.

```
TV Settings rail
  Theme → Playback (aspect+density) → Sources → Accessibility → Country → Privacy → About
Phone Aika Stream hub
  Appearance → Playback → Country → Playlist → EPG → Accessibility → Privacy → About
Super-app hub
  Mind portability → Appearance → Audio ducking → Playback → …  (no Privacy wipe)
```

### NOT in scope (CEO)

PIN/profiles, ads opt-out, Smart Audio on TV, surf mode, EPG offset, resume, sleep, UA editor, decoder, buffer, external player, cloud prefs, TV backup, `core_ui` font rewrite, Play listing/release yml.

### Dream state delta

This packet makes Settings the home for font and captions. It does not make Aika Stream match TiviMate. That is resume + sleep + UA, sequenced after merge.

### Failure modes

| CODEPATH | FAILURE | RESCUED | TEST | USER SEES | LOGGED |
| --- | --- | --- | --- | --- | --- |
| Font persist | prefs fail | Y | Y | stale size | N |
| Captions persist | prefs fail | Y | Y | stale on/off | N |
| Captions On, no tracks | no track | Y | plan | no captions until track | N |
| Density on Fire TV | no D-pad | Task 3 | Y | cannot change | N |
| Delete data | store error | Y | existing | dialog | N |
| Privacy on super-app | wrong shell | accepted cut | negative test | no tile | N |

No CRITICAL GAP after accepted Task 3 D-pad and Task 5 shell cut.

### Taste decisions (gate)

1. Accessibility as its own rail vs under Playback — kept rail (CV-008 discoverability).
2. Follow-ups: two P2 rows vs eight TODOS.md bullets — two P2 (resume+sleep, audio language).

No User Challenge (Codex missing; native did not demand reversing the user's Slice 1 direction).

### Design review (Phase 2)

Native INPUT: design 0c755f770922649d0ee8da6585fc1724bfef502e345477ba7b887ea848628918
Codex INPUT: n/a
outside_status: unavailable (`gpt-6-astra` not supported on ChatGPT account; `GSTACK_CODEX_MODEL` unset — do not guess). Rechecked 2026-09-22.
host: cursor
outside_provider: codex
phase: design
source: in-host
Tag: `[subagent-only]`.
Mockups: skipped — OPERATE/APP UI settings chrome; success is discoverable Off/On and real Library scale, not a marketing frame (P5). Classifier: OPERATE / APP UI.
DESIGN.md: none. Universal App UI rules + existing `TvSettingsScreen` rail / `SettingsHubScreen` list.

**Claude SUBAGENT (design completeness)** — [chief-ux-officer](9dd80db4-239e-4377-b9ea-443f4834f6a8)
Verdict: reject Slice 1 as written until locks. Captions "stream default" is a lie (`_applyCaptionPreferenceIfNeeded` returns when `languageCode == null`). `tvFontMode` scales `TvChannelGrid` only; live browse is `ChannelLibraryGrid`. `ChannelGridDensitySection` is phone-column-only (`phoneGridColumns` below 600px). Compact hub already shows Audio ducking. TV delete confirm autofocuses Delete.

**Codex SAYS (design critique):** unavailable. Same 400 as CEO. Fix: `GSTACK_CODEX_MODEL=<supported-model>`. Outside coverage missing.

```
DESIGN OUTSIDE VOICES — LITMUS SCORECARD:
  1. Brand unmistakable     YES  N/A  N/A
  2. One visual anchor      YES  N/A  N/A  (TV rail + one detail)
  3. Scannable headlines    YES  N/A  N/A
  4. One job per section    NO   N/A  N/A  (Playback+density was a lie; fixed)
  5. Cards necessary        YES  N/A  N/A  (none added)
  6. Motion improves        n/a  N/A  N/A
  7. Premium without shadows YES N/A  N/A
Hard rejections: none after auto-fixes. Unresolved "stream default" copy was a P5 honesty hit, not a marketing hard rejection.
```

Step 0: initial design completeness 4/10 (placebo font, dishonest captions, density lie, audio leak). 10 is sofa can change font+captions from Settings and see Library names + matching-track captions actually change.
Focus: all 7 passes (autoplan P1).

Pass 1 Information Architecture: 5/10 → 9/10
First: Accessibility (font, captions). Second: Playback aspect. Third: Country. Sources after Country. Privacy last. About extra stop.
Auto-fix (P5): TV rail Theme → Accessibility → Playback → Country → Sources → Privacy → About. Drop density from Playback (phone-only control).

Pass 2 States: 4/10 → 8/10 after auto-fixes.
```
  FEATURE              | LOADING | EMPTY | ERROR | SUCCESS | PARTIAL
  ---------------------|---------|-------|-------|---------|--------
  Text size            | last saved | Standard selected | persist fail keeps last (existing notifier) | check on chosen row; Library names scale | Settings chrome unchanged
  Captions Off         | n/a | Off checked | persist fail keeps last | player does not auto-select | n/a
  Captions On + language | n/a | n/a | no matching track: stay On, no captions until track exists | next stream selects matching subtitle | status shows saved code
  Captions On + no language | n/a | status: "No language saved — pick one in the player." | n/a | enabled stored; player no-ops | honest partial, not a fake On
  Country              | "Loading countries…" (existing) | disabled "Load channels first…" | n/a | filter applies to browse | n/a
  Privacy delete       | n/a | n/a | "Could not delete…" dialog | "Local data deleted" | confirm focuses Cancel
  Audio ducking        | n/a | hidden on ShellId.tv | n/a | super-app only | n/a
  Density              | n/a | n/a | n/a | phone Playback only | absent on TV
```

Pass 3 Journey: 5/10 → 8/10
```
  STEP | USER DOES              | USER FEELS                 | PLAN
  1    | Opens TV Settings      | "this is the living room"  | Theme first; Accessibility second
  2    | Accessibility → Large  | names get easier to read   | Library tiles scale; chrome does not
  3    | Captions On, no lang   | not lied to                | status says pick in player
  4    | Captions On, lang saved| next live show is captioned| existing apply path
  5    | Country                | library matches the sofa   | same picker as phone
  6    | Phone Privacy          | wipe without app-info      | Delete first; Cancel focused
  7    | Compact Audio tile     | gone                       | wrapped to ShellId.mobile
```
5-sec: rail finds Accessibility. 5-min: font visibly larger in Library. 5-year: Settings is still the home; language picker is CV-016.

Pass 4 AI slop: 6/10 → 8/10. Hard rejection none. Vague "stream default" struck. Captions are Off/On rows (existing Privacy `_ConsentOption` pattern), not a Material Switch on Fire TV. No new cards.

Pass 5 Design system: 7/10 → 8/10. No DESIGN.md. Reuse `TvFocusable`, `CountrySettingsTile`, `TvPrivacySection`. New widget lives next to Playback in `feature_iptv`. Phone hub stays a list; TV stays rail/detail.

Pass 6 Responsive/a11y: 4/10 → 8/10. D-pad: every new TV option is `TvFocusable`. Captions not a Switch. Density not on 10-foot. Audio hidden on compact TV hub. Confirm autofocus Cancel. Touch: phone Switch OK. Contrast: existing scheme. Text size does not scale Settings (stated). No haptics on TV.

Pass 7 Decision register (unscored):
- Captions copy vs CEO "stream default": design wins (code evidence). Keep player contract (no fallback language).
- Density on TV vs drop: drop (P5). Wiring TV columns is a later completeness packet, not this one.
- Font on phone Accessibility: show it — Library is shared and will scale.

NOT in scope (design): TV grid-column density, caption appearance, language picker, Settings chrome scale, changing `_applyCaptionPreferenceIfNeeded`.

Taste (gate): drop TV density vs wire `_columnCountFor` to `ChannelGridDensity`. Auto-decided drop. Wire later if sofa users ask for fewer tiles.

<!-- autoplan-baseline-edits:design {"sourceSha256":"735981454e9dc90a4861fb6ce211da2bafe9ca54acc59f135bdcde7cc03aa2e3","replacements":[{"oldText":"| Packet | Slice 1: Accessibility (font + captions) + country on TV + privacy on phone Aika Stream + grid density on TV Playback |\n| Manifest | Add `accessibility`; widen `country` and `privacy` `visibleForShells` |\n| Font | Reuse `tvFontModeProvider` (`standard` / `large` / `extraLarge`) |\n| Captions | Reuse `captionPreferenceProvider` (enabled + language code) |\n| Country | Reuse `CountrySettingsTile` on TV as a focusable detail pane, do not fork the picker |\n| Privacy on phone | Reuse `TvPrivacySection` widgets or extract shared list; same delete-local-data path |\n| Density | Mount `ChannelGridDensitySection` in `TvPlaybackSection` |\n| Audio ducking | Stay mobile-super-app only. Not Aika Stream TV |\n| PiP / haptics | Stay phone Playback. TV Playback stays aspect + density |\n| Parental / ads / decoder | Out of this packet |","newText":"| Packet | Slice 1: Accessibility (font + captions) + country on TV + privacy on phone Aika Stream. Grid density stays phone Playback only |\n| Manifest | Add `accessibility` immediately after `theme`; move `country` before `sources` so TV-visible order is Theme → Accessibility → Playback → Country → Sources → Privacy. Widen `country` and `privacy` `visibleForShells` |\n| Font | Reuse `tvFontModeProvider`. Apply `.scale` to live `ChannelLibraryGrid` tile names, not only `TvChannelGrid` |\n| Captions | Reuse `captionPreferenceProvider`. Settings is Off/On only. Player still applies only when `enabled && languageCode != null`. Copy must not claim stream default |\n| Country | Reuse `CountrySettingsTile` on TV as a focusable detail pane, do not fork the picker |\n| Privacy on phone | Reuse `TvPrivacySection` widgets or extract shared list; same delete-local-data path. Phone: Delete first. Confirm autofocus Cancel |\n| Density | Phone Playback / explorer only. Do not mount on 10-foot `TvPlaybackSection` (`phoneGridColumns` is ignored above 600px) |\n| Audio ducking | Stay `ShellId.mobile` only. Compact Aika Stream hub currently shows the tile — wrap it |\n| PiP / haptics | Stay phone Playback. TV Playback stays aspect ratio only |\n| Parental / ads / decoder | Out of this packet |"},{"oldText":"- `tvFontModeProvider` applied in `tv_channel_grid.dart`, never in Settings.","newText":"- `tvFontModeProvider` applied in `tv_channel_grid.dart` only. Live Aika Stream browse is `ChannelLibraryGrid`, which does not watch the scale today."},{"oldText":"packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart  [modify: density]","newText":"packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart [modify: apply tvFontMode]"},{"oldText":"- [ ] Add `IptvSettingsSectionId.accessibility` with label `Accessibility`, icon `Icons.accessibility_new`, visible on `{ShellId.mobile, ShellId.tv}`, TV label override `Accessibility`.\n- [ ] Set `country.visibleForShells` to `{ShellId.mobile, ShellId.tv}`.","newText":"- [ ] Add `IptvSettingsSectionId.accessibility` with label `Accessibility`, icon `Icons.accessibility_new`, visible on `{ShellId.mobile, ShellId.tv}`, TV label override `Accessibility`. Insert the descriptor immediately after `theme`.\n- [ ] Place `country` before `sources` in `iptvSettingsSections` so TV-visible rail order is Theme → Accessibility → Playback → Country → Sources → Privacy (About is the extra Airo Apps / info stop).\n- [ ] Set `country.visibleForShells` to `{ShellId.mobile, ShellId.tv}`."},{"oldText":"1. Text size: three `TvFocusable` options mapped to `TvFontMode.standard|large|extraLarge`, labels \"Standard\", \"Large\", \"Extra large\". Selecting calls `tvFontModeProvider.notifier.setTvFontMode`.\n2. Captions: on/off only via `captionPreferenceProvider.notifier.setCaptionsEnabled`. Copy: \"On uses the stream default; pick a language from the player.\" Do not show a language picker in this packet. Font copy: \"Text size applies to the channel grid.\" Preferred caption/audio language is CV-016.\n3. Use `TvFocusable` so the same widget works in the TV detail pane.","newText":"1. Text size: three `TvFocusable` options mapped to `TvFontMode.standard|large|extraLarge`, labels \"Standard\", \"Large\", \"Extra large\". Selecting calls `tvFontModeProvider.notifier.setTvFontMode`. Font copy: \"Text size applies to channel names in the library.\"\n2. Captions: Off/On only via `setCaptionsEnabled`. No language picker. TV chrome: two `TvFocusable` rows with a check on the selected row — not a Switch. Phone may use a Switch. Copy (exact): \"On reapplies the last language you picked in the player. If you have not picked one yet, captions stay off until you do.\" Do not write \"stream default.\" Status under the control: if `languageCode == null`, \"No language saved — pick one in the player.\"; else \"Saved language: {code}.\" Do not change `_applyCaptionPreferenceIfNeeded`. Preferred caption/audio language is CV-016.\n3. Use `TvFocusable` for every TV option including captions Off/On."},{"oldText":"### Task 3: Grid density on TV Playback\n\n**Files:**\n- Modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart`\n- Test: extend existing TV playback tests if present; otherwise add a widget test that `TvPlaybackSection` contains `ChannelGridDensitySection`.\n\n- [ ] After aspect-ratio options (before `playbackSettingsExtraSectionsProvider`), mount `const ChannelGridDensitySection()`.\n- [ ] Wrap density radios in `TvFocusable` if `RadioListTile` is not D-pad selectable on Fire TV. Probe with existing `ChannelGridDensitySection` tests; if TV cannot change density from this widget, add a TV-specific option list that calls the same notifier (do not fork the enum).","newText":"### Task 3: Apply text size to live Library grid\n\n**Files:**\n- Modify: `packages/feature_iptv/lib/presentation/tv_ux/sections/channel_library_grid.dart`\n- Modify: `packages/feature_iptv/test/iptv/presentation/tv_ux/channel_library_grid_test.dart`\n- Do not modify: `packages/feature_iptv/lib/presentation/tv/settings/tv_playback_section.dart` (no density on 10-foot Playback)\n\n- [ ] Watch `tvFontModeProvider` in `ChannelLibraryGrid` (promote to `ConsumerStatefulWidget` if needed). Multiply channel-name `fontSize` on `MediaCard` / `_CompactGridMediaCard` / `_HorizontalMediaCard` by `TvFontMode.scale` (`standard=1.0`, `large=1.25`, `extraLarge=1.5`). Do not scale Settings chrome. Do not rewrite `core_ui` text theme.\n- [ ] Widget test: Extra large enlarges Library names vs Standard. Existing overflow tests stay green; if Extra large overflows a dense phone tile, drop subtitle the same way `compactGridShowSubtitle` already does at 5-up — do not clip names.\n- [ ] Assert `TvPlaybackSection` does **not** contain `ChannelGridDensitySection`. Phone Playback keeps density."},{"oldText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection`; `country` → a TV-hosted `CountrySettingsTile` (or a small `TvCountrySection` that embeds the same picker). Remove those ids from the \"never selected\" shrink list.\n- [ ] Tests: selecting Accessibility rail shows font options; selecting Country shows the country tile. Existing theme/playback/sources/privacy tests stay green.","newText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection`; `country` → a TV-hosted `CountrySettingsTile` (or a small `TvCountrySection` that embeds the same picker). Remove those ids from the \"never selected\" shrink list.\n- [ ] Tests: rail order Theme, Accessibility, Playback, Country, Sources, Privacy, then About. Selecting Accessibility shows font options and captions Off/On rows; selecting Country shows the country tile. Existing theme/playback/sources/privacy tests stay green."},{"oldText":"- [ ] Add Privacy tile only on Aika Stream shells (`ShellId.tv` compact and the Aika Stream phone hub). Super-app `ShellId.mobile` does not get this tile. Host `TvPrivacySection` or a shared extract. Delete-local-data must work on phone. On phone, lead with Delete local data; hide or disable the telemetry share toggle when `PlatformMediaLogger` is not bootstrapped.","newText":"- [ ] Add Privacy tile only on Aika Stream shells (`ShellId.tv` compact and the Aika Stream phone hub). Super-app `ShellId.mobile` does not get this tile. Host `TvPrivacySection` or a shared extract. Delete-local-data must work on phone. On phone, lead with Delete local data; hide the telemetry share toggle when `PlatformMediaLogger` is not bootstrapped. Confirm dialog autofocus **Cancel** (TV today autofocuses Delete — change both shells)."},{"oldText":"- [ ] Do not add Audio ducking to `ShellId.tv`. Keep it `ShellId.mobile` only (super-app).\n- [ ] Tests: hub shows Accessibility and Privacy; tapping Privacy can reach \"Delete local data\".","newText":"- [ ] Wrap the existing Audio Settings `ListTile` in `shellId == ShellId.mobile`. Compact Aika Stream hub currently shows it; hide it on `ShellId.tv`.\n- [ ] Tests: super-app hub has Accessibility, no Privacy; Aika Stream compact hub has Accessibility + Privacy, no Audio Settings; tapping Privacy can reach \"Delete local data\" with Cancel focused on the confirm dialog."},{"oldText":"| Font Large on TV Settings | Channel names in Library/Watch chrome enlarge; restart keeps Large |\n| Captions on from Settings | Next stream with a matching subtitle track enables captions without opening the player menu first |\n| Country on TV | Filter applies to browse; matches phone behavior |\n| Density on TV Playback | Library grid column count changes |\n| Privacy on phone hub | Delete local data wipes sources/favorites like TV |\n| Audio ducking | Still absent from Aika Stream TV rail and `ShellId.tv` compact hub |\n| Fire TV D-pad | Every new option is `TvFocusable`; Back returns to rail |","newText":"| Font Large on TV Settings | Channel names in live Library enlarge; restart keeps Large; Settings rail labels unchanged |\n| Captions On + saved language | Next stream with a matching subtitle track enables captions without opening the player menu first |\n| Captions On + no language | Preference stores enabled; player stays without captions until a language is picked in-player |\n| Country on TV | Filter applies to browse; matches phone behavior |\n| Density | Unchanged on phone Playback; absent from TV Playback |\n| Privacy on phone hub | Delete local data first; confirm focuses Cancel; wipes sources/favorites like TV |\n| Audio ducking | Absent from Aika Stream TV rail and `ShellId.tv` compact hub |\n| Fire TV D-pad | Every new option is `TvFocusable`; captions are Off/On rows; Back returns to rail |"},{"oldText":"- Font scale currently hits the channel grid. If Settings itself does not scale, that is acceptable for Slice 1; do not rewrite `core_ui` text theme in this packet.","newText":"- Font scale today hits only `TvChannelGrid`, not live `ChannelLibraryGrid`. Slice 1 must apply scale to Library names. If Settings chrome does not scale, that is acceptable; do not rewrite `core_ui` text theme."}]} -->
<!-- autoplan-accepted:design -->
- Apply `tvFontModeProvider.scale` to live `ChannelLibraryGrid` tile names (`MediaCard`, `_CompactGridMediaCard`, `_HorizontalMediaCard`). Do not claim Watch chrome scales. Do not rewrite `core_ui` text theme.
  Verify: Large then restart; Library names larger; Settings rail labels unchanged; `tv_channel_grid.dart` path still scales.
- Captions Settings is Off/On only. TV: two `TvFocusable` check rows, not a Switch. Copy: "On reapplies the last language you picked in the player. If you have not picked one yet, captions stay off until you do." Status: `languageCode == null` → "No language saved — pick one in the player." Else "Saved language: {code}." Do not write "stream default." Do not change `_applyCaptionPreferenceIfNeeded` (still requires enabled + languageCode).
  Verify: widget test On writes `caption_preference_enabled`; no language list; copy string present; player still no-ops when languageCode is null.
- Do not mount `ChannelGridDensitySection` on 10-foot `TvPlaybackSection`. Density remains phone Playback + explorer (`phoneGridColumns` only below 600px).
  Verify: TV Playback test has no density radios; phone Playback still has them.
- TV rail order (manifest list, TV-visible): Theme → Accessibility → Playback → Country → Sources → Privacy → About.
  Verify: widget test rail order; Back from each new detail returns to rail.
- Hide Audio ducking unless `shellId == ShellId.mobile`. Compact Aika Stream hub currently shows it; wrap that tile.
  Verify: `SettingsHubScreen(shellId: ShellId.tv)` has no Audio Settings tile.
- Phone Privacy: Delete local data first; hide telemetry when logger absent. Confirm dialog autofocus Cancel (TV today autofocuses Delete — change both shells).
  Verify: phone Aika Stream hub Privacy; super-app negative test; confirm initial focus is Cancel.
<!-- /autoplan-accepted:design -->

### DX review (Phase 2.5)

Native INPUT: dx 806a67615af29ca75a464daf05a3302019fcec1563fdd9678acb0112ebabd942
Codex INPUT: n/a
outside_status: unavailable (`gpt-6-astra` not supported on ChatGPT account; `GSTACK_CODEX_MODEL` unset — do not guess). Rechecked 2026-09-22.
host: cursor
outside_provider: codex
phase: dx
source: in-host
Tag: `[subagent-only]`.
Mode: DX POLISH (autoplan override; existing settings wiring, not a public SDK).
Persona: Flutter engineer adding IPTV settings widgets in this repo (not a pub.dev consumer).
TTHW target: Competitive — named `flutter test` recipe < 5 min after codegen.
Magical moment: copy-paste test command proves Large persist + captions On with `languageCode: 'eng'`.

**Claude SUBAGENT (DX)** — [flutter-architect](28650f42-d281-4f24-b6a1-d1b24388f40f)
Verdict: reject as written. Captions/font/density recap vs Task 2 contradict (CEO accepted block is immutable; implementer follows later Design/DX locks). `MediaCard` has no `fontSize`. Hub does not iterate the manifest. `PlatformMediaLogger` has no `isBootstrapped`. `CountrySettingsTile` is a mobile `ListTile`. Dual-layout widget has no constructor.

**Codex SAYS (DX):** unavailable. Same 400 as CEO/Design. Fix: `GSTACK_CODEX_MODEL=<supported-model>`.

```
DX DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           cursor (in-host)  Codex  Consensus
  ──────────────────────────────────── ─────── ─────── ─────────
  1. Getting started < 5 min?          N       N/A    N/A
  2. API/CLI naming guessable?         N       N/A    N/A
  3. Error messages actionable?        Y*      N/A    N/A
  4. Docs findable & complete?         N       N/A    N/A
  5. Upgrade path safe?                Y       N/A    N/A
  6. Dev environment friction-free?    Y*      N/A    N/A
═══════════════════════════════════════════════════════════════
* captions status string is good; prefs save stays existing swallow (P3). Tests exist once recipe is named.
CONFIRMED requires native + outside. Outside unavailable: all Consensus N/A.
```

Step 0: product type = in-repo Flutter library/widgets (term matcher fired; not a public SDK). Initial DX completeness 3/10. 10 is named constructors + one copy-paste test recipe.

```
TARGET DEVELOPER PERSONA
========================
Who:       Flutter engineer on Aika Stream / feature_iptv
Context:   Implements Slice 1 from this plan after CEO+Design locks
Tolerance: ~5 min to first green focused test
Expects:   Playback-shaped widgets, ProviderScope overrides, exact copy strings
```

Empathy (first person): I open the plan. Locked table says no density on TV. CEO accepted block still says mount density. Task 3 says multiply `fontSize` on `MediaCard`. I open `media_card.dart` — no such parameter. I widen privacy for mobile because Task 1 says so, then Task 5 says super-app must not show it. The hub does not iterate the list, so I am guessing. I look for `PlatformMediaLogger.isBootstrapped`. It does not exist.

```
COMPETITIVE DX BENCHMARK
=========================
Tool              | TTHW      | Notable DX Choice
Playback settings | ~3 min    | Two widgets: phone screen + TV section
This plan (before)| ~8 hops   | Dual anonymous widget, no recipe
This plan (after) | < 5 min   | forTv flag + copy-paste flutter test
```
Search unavailable — Aside not running. Reference: in-repo Playback pair.

Journey:
```
STAGE           | DEVELOPER DOES                         | STATUS
1. Discover     | This plan + docs/designs/aika-stream-settings.md | ok
2. Install      | existing workspace                     | ok
3. Hello World  | copy-paste flutter test in Task 6      | fixed
4. Real Usage   | forTv / showTelemetry / MediaQuery wrap| fixed
5. Debug        | captions status; delete dialogs kept   | ok
6. Upgrade      | prefs keys already exist; no migration | ok
```

Pass 1 Getting Started: 3/10 → 8/10 after recipe.
Pass 2 API: 3/10 → 8/10 after constructors + MediaQuery seam.
Pass 3 Errors: 5/10 → 7/10 (keep delete dialogs, skip notifier rewrite P3).
Pass 4 Docs: 4/10 → 8/10 (design lock wins over CEO recap; implementer note).
Pass 5 Upgrade: 8/10. Prefs keys already in the wild.
Pass 6 Env: 7/10 → 8/10 (named test files next to existing IPTV tests).
Pass 7 Community: n/a (in-repo packet).
Pass 8 Measurement: 3/10 → 4/10 (focused tests are the metric; no TTHW telemetry this packet).

Overall ~7.5/10 after auto-fixes. TTHW implementer < 5 min recipe.

NOT in scope (DX): public SDK docs, notifier rewrite, core_ui MediaCard API, ICAST bump, playground.

Implementer note: `<!-- autoplan-accepted:ceo -->` is retained byte-for-byte. Captions copy, font copy, and density placement in that block are superseded by Design + this DX block. Do not re-mount density on TV Playback. Do not write "stream default."

<!-- autoplan-baseline-edits:dx {"sourceSha256":"ed97920cb1d8b2a77b0ff3ad16ac0659ec0ca1f96eec2d0e721de9383118d8d2","replacements":[{"oldText":"| Manifest | Add `accessibility` immediately after `theme`; move `country` before `sources` so TV-visible order is Theme → Accessibility → Playback → Country → Sources → Privacy. Widen `country` and `privacy` `visibleForShells` |","newText":"| Manifest | Add `accessibility` immediately after `theme`; move `country` before `sources` so TV-visible order is Theme → Accessibility → Playback → Country → Sources → Privacy. Widen `country` only. Keep `privacy` TV-only in the manifest; compact hub special-cases Privacy |"},{"oldText":"| Country | Reuse `CountrySettingsTile` on TV as a focusable detail pane, do not fork the picker |","newText":"| Country | Reuse `CountrySettingsTile({bool forTv = false})`. TV wraps the same `showFilterOptionDialog` in `TvFocusable`. Empty country list stays focusable with existing subtitle. Do not fork the picker |"},{"oldText":"| Privacy on phone | Reuse `TvPrivacySection` widgets or extract shared list; same delete-local-data path. Phone: Delete first. Confirm autofocus Cancel |","newText":"| Privacy on phone | `TvPrivacySection({bool showTelemetry = true, bool deleteFirst = false})`. Compact hub: `showTelemetry: false, deleteFirst: true`. No `PlatformMediaLogger` probe (no `isBootstrapped`). Confirm autofocus Cancel |"},{"oldText":"packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart   [modify: add accessibility; widen country/privacy]","newText":"packages/feature_iptv_core/lib/src/iptv_settings_manifest.dart   [modify: add accessibility; widen country; privacy stays TV]"},{"oldText":"packages/feature_iptv/test/presentation/screens/settings/\n  accessibility_settings_section_test.dart                       [new]","newText":"packages/feature_iptv/test/iptv/presentation/screens/settings/\n  accessibility_settings_section_test.dart                       [new]"},{"oldText":"- [ ] Add `IptvSettingsSectionId.accessibility` with label `Accessibility`, icon `Icons.accessibility_new`, visible on `{ShellId.mobile, ShellId.tv}`, TV label override `Accessibility`. Insert the descriptor immediately after `theme`.","newText":"- [ ] Add `IptvSettingsSectionId.accessibility` with label `Accessibility`, icon `Icons.accessibility_new`, visible on `{ShellId.mobile, ShellId.tv}`. Insert immediately after `theme`. Do not add a redundant TV label override. Update the manifest file header so it no longer says TV omits country."},{"oldText":"- [ ] Set `privacy.visibleForShells` to `{ShellId.mobile, ShellId.tv}` (phone compact Aika Stream and TV both need delete-local-data). Keep the comment that telemetry no-ops until `main.dart` bootstraps `PlatformMediaLogger`; the delete-local-data half is still valid on phone.\n- [ ] Update manifest tests: TV visible set includes accessibility, country, privacy; mobile includes accessibility and privacy.","newText":"- [ ] Leave `privacy.visibleForShells` as `{ShellId.tv}`. The phone hub does not iterate the manifest; compact Aika Stream special-cases Privacy in Task 5. Super-app must not gain a Privacy tile because of a widened set.\n- [ ] Update manifest tests: TV visible set includes accessibility, country, privacy; mobile includes accessibility, not privacy."},{"oldText":"- Create: `packages/feature_iptv/test/presentation/screens/settings/accessibility_settings_section_test.dart`\n- Export from `packages/feature_iptv/lib/feature_iptv.dart` if other settings widgets are exported that way.\n\nThe widget is a `ListView` (TV detail) / column (phone) of:","newText":"- Create: `packages/feature_iptv/test/iptv/presentation/screens/settings/accessibility_settings_section_test.dart`\n- Export next to `CountrySettingsTile` in `packages/feature_iptv/lib/feature_iptv.dart`.\n\nConstructor: `AccessibilitySettingsSection({required bool forTv})`. Mirror Playback: TV detail is a `ListView` of `TvFocusable` rows like `TvPlaybackSection` (the rail already hosts one scroller). Phone is a `Column`/`ListView` with a Switch for captions. Do not invent a dual anonymous layout.\n\nThe widget contains:"},{"oldText":"- [ ] Watch `tvFontModeProvider` in `ChannelLibraryGrid` (promote to `ConsumerStatefulWidget` if needed). Multiply channel-name `fontSize` on `MediaCard` / `_CompactGridMediaCard` / `_HorizontalMediaCard` by `TvFontMode.scale` (`standard=1.0`, `large=1.25`, `extraLarge=1.5`). Do not scale Settings chrome. Do not rewrite `core_ui` text theme.","newText":"- [ ] Watch `tvFontModeProvider` in `ChannelLibraryGrid` (promote to `ConsumerStatefulWidget` if needed). Named seam: wrap the `MediaCard` branch in `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), ...)`. Local `_CompactGridMediaCard` / `_HorizontalMediaCard` multiply their hardcoded `fontSize` by `TvFontMode.scale`. Do not add a `fontSize` parameter to `MediaCard` / `AiroRailCard`. Do not rewrite `core_ui` `ThemeData`. Do not scale Settings chrome."},{"oldText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection`; `country` → a TV-hosted `CountrySettingsTile` (or a small `TvCountrySection` that embeds the same picker). Remove those ids from the \"never selected\" shrink list.","newText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection(forTv: true)`; `country` → `CountrySettingsTile(forTv: true)` (add `forTv` + `TvFocusable` around the existing `showFilterOptionDialog`; when no countries, keep the row focusable with the existing subtitle). Remove those ids from the \"never selected\" shrink list."},{"oldText":"- [ ] Add Accessibility tile (manifest labels) pushing a small `Scaffold` that hosts `AccessibilitySettingsSection` (phone: no TV rail chrome).\n- [ ] Add Privacy tile only on Aika Stream shells (`ShellId.tv` compact and the Aika Stream phone hub). Super-app `ShellId.mobile` does not get this tile. Host `TvPrivacySection` or a shared extract. Delete-local-data must work on phone. On phone, lead with Delete local data; hide the telemetry share toggle when `PlatformMediaLogger` is not bootstrapped. Confirm dialog autofocus **Cancel** (TV today autofocuses Delete — change both shells).","newText":"- [ ] Add Accessibility tile immediately after Appearance (manifest labels) pushing a `Scaffold` that hosts `AccessibilitySettingsSection(forTv: false)`.\n- [ ] Add Privacy tile only when `shellId == ShellId.tv` (compact Aika Stream hub). Super-app `ShellId.mobile` does not get it. Host `TvPrivacySection(showTelemetry: false, deleteFirst: true)`. Keep existing delete failure/success dialogs. Confirm autofocus **Cancel** on both shells (TV today autofocuses Delete)."},{"oldText":"### Task 6: Analyzer + focused tests\n\n- [ ] `dart analyze` on `packages/feature_iptv_core`, `packages/feature_iptv`, `app` (tv settings files).\n- [ ] `flutter test` the files named above. Do not run the full workspace matrix.","newText":"### Task 6: Analyzer + focused tests\n\nCopy-paste hello world (implementer TTHW, target < 5 min after codegen):\n\n```\ncd packages/feature_iptv && flutter test \\\n  test/iptv/domain/iptv_settings_manifest_test.dart \\\n  test/iptv/presentation/screens/settings/accessibility_settings_section_test.dart \\\n  test/iptv/presentation/tv_ux/channel_library_grid_test.dart \\\n  test/iptv/presentation/tv/settings/tv_playback_section_test.dart\n```\n\nOverride recipe (put in the Accessibility widget test): `ProviderScope(overrides: [sharedPreferencesProvider, tvFontModeProvider, captionPreferenceProvider])` with `languageCode: 'eng'` when proving captions On + saved language. Match `tv_font_mode_provider_test.dart`.\n\n- [ ] `dart analyze` on `packages/feature_iptv_core`, `packages/feature_iptv`, `app` (tv settings files).\n- [ ] `flutter test` the files named above plus `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart` and `app/test/features/settings/presentation/screens/settings_hub_screen_test.dart`. Do not run the full workspace matrix."},{"oldText":"- Privacy telemetry copy on phone is honest only if the logger is bootstrapped. If `main.dart` still does not, show the delete-local-data block first and keep telemetry copy TV-primary, or disable the share toggle when the logger is absent.","newText":"- Privacy: do not probe `PlatformMediaLogger` (no `isBootstrapped`; default is already `AiroNoOpAnalyticsService`). Compact hub passes `showTelemetry: false`. Prefs notifiers keep swallowing save failures this packet (existing pattern); do not rewrite them."}]} -->
<!-- autoplan-accepted:dx -->
- `AccessibilitySettingsSection({required bool forTv})`. TV: `ListView` of `TvFocusable` rows like `TvPlaybackSection`. Phone: `Column`/`ListView` + captions Switch. Export next to `CountrySettingsTile`.
  Verify: `forTv: true` has no Material Switch; phone test uses Switch.
- Library text size seam: wrap the `MediaCard` branch in `MediaQuery` `textScaler: TextScaler.linear(scale)`. Multiply fontSize only on local `_CompactGridMediaCard` / `_HorizontalMediaCard`. Do not add `fontSize` to `MediaCard`.
  Verify: Extra large enlarges Library names; no `core_ui` MediaCard signature change.
- `CountrySettingsTile({bool forTv = false})`. TV: `TvFocusable` + existing `showFilterOptionDialog`. Empty list stays focusable with existing subtitle.
  Verify: Fire TV can open country picker; no second picker widget.
- Keep `privacy.visibleForShells` as `{ShellId.tv}`. Compact hub (`shellId == ShellId.tv`) special-cases `TvPrivacySection(showTelemetry: false, deleteFirst: true)`. Super-app hub does not.
  Verify: manifest mobile set has no privacy; compact hub has Delete local data; super-app does not.
- Confirm dialog autofocus Cancel on both shells. Do not probe `PlatformMediaLogger`. Do not rewrite prefs notifiers.
  Verify: confirm initial focus Cancel; no `isBootstrapped` call.
- Copy-paste Task 6 `flutter test` recipe plus `ProviderScope` override with `languageCode: 'eng'` for captions On + language.
  Verify: recipe present in plan; Accessibility test file lives under `test/iptv/presentation/`.
<!-- /autoplan-accepted:dx -->

### Eng review (Phase 3)

Native INPUT: eng 2bca5820aac2be8f36b272d56b99071eeeafa0ce379d5ecf392562fadf66f617
Codex INPUT: n/a
outside_status: unavailable (`gpt-6-astra` not supported on ChatGPT account; `GSTACK_CODEX_MODEL` unset — do not guess). Rechecked 2026-09-23; probe INCONCLUSIVE fail-open then HTTP 400.
host: cursor
outside_provider: codex
phase: eng
source: in-host
Tag: `[subagent-only]`.
Methodology: autoplan-eng-methodology-PjplDD ranges 1–600, 601–1200, 1201–1800/EOF (1800 lines). Snapshot dir `autoplan-eng-BkNBrF`.
Mode: FULL_REVIEW. Complexity check triggered (8+ files). Autoplan override: never reduce (P2). Packet stays Slice 1; Eng amends seams.

**Claude SUBAGENT (eng)** — [flutter-architect](eecb17c4-c49d-4305-a4a0-0dd6bb36a43f)
Verdict: do not implement as written. Slice 1 intent is sound. Task 3 will double-scale or overflow Fire TV if followed literally. Library already wraps tiles in MediaQuery (`channel_library_grid.dart` 975–989, landed in `4120f32f`). TV country must use `showTvLongListPicker`, not `showFilterOptionDialog`.

**Codex SAYS (eng — architecture challenge):** unavailable. Same 400 as CEO/Design/DX. Fix: `GSTACK_CODEX_MODEL=<supported-model>`. Outside coverage missing.

```
ENG DUAL VOICES — CONSENSUS TABLE:
═══════════════════════════════════════════════════════════════
  Dimension                           Claude  Codex  Consensus
  ──────────────────────────────────── ─────── ─────── ─────────
  1. Architecture sound?               N*      N/A    N/A
  2. Test coverage sufficient?         N       N/A    N/A
  3. Performance risks addressed?      Y*      N/A    N/A
  4. Security threats covered?         Y       N/A    N/A
  5. Error paths handled?              Y*      N/A    N/A
  6. Deployment risk manageable?       Y       N/A    N/A
═══════════════════════════════════════════════════════════════
* after Eng auto-fixes: one scale seam, TV rowExtent, showTvLongListPicker, privacy tests.
CONFIRMED requires native + outside. Outside unavailable: all Consensus N/A.
Tag: `[subagent-only]`.
```

Search check: Aside not running. WebSearch (Flutter TextScaler, 2026 docs): do not multiply `TextStyle.fontSize` under a `MediaQuery` `textScaler` — Flutter already applies the scaler ([Layer 1](https://docs.flutter.dev/release/breaking-changes/deprecate-textscalefactor)). Nonlinear Android 14 scalers have no general inverse.

Prior learning applied: `browse_grid_one_preview_not_reels` (confidence 9/10, 2026-09-19) — Library is the live sofa grid; font work belongs there, not a second grid. `firetv_aftsss_tv_profile_gate` noted; Slice 1 is Dart-only.

Retrospective: `4120f32f` already hid compact-TV Audio and added the per-tile MediaQuery wrap. Plan "does not watch the scale today" is stale. Do not treat Task 3 as greenfield.

#### Step 0 Scope Challenge

1. Existing code: `tvFontModeProvider`, `captionPreferenceProvider`, `channelFiltersProvider`, `CountrySettingsTile`, `TvPrivacySection`, `iptvSettingsSections`, `TvPlaybackSection` aspect-only, hub hardcoded tiles, Library MediaQuery wrap, `showTvLongListPicker` on browse (`filter_row.dart`, `airo_tv_shell.dart`). Captions apply path `video_player_widget.dart:2933` no-ops unless `enabled && languageCode != null`.
2. Minimum: Accessibility widget + manifest + hub/rail routing + one Library scale seam + country `forTv` + privacy constructor. Do not add stores, player pipeline, core_ui theme, ICAST.
3. Complexity: 8+ files (manifest, accessibility+test, library+test, rail+test, hub+test, country tile, privacy+test). Smell acknowledged. Override: never reduce. Same sofa win cannot drop Country or Privacy without losing the packet.
4. Custom vs built-in: MediaQuery textScaler is the framework built-in. Dual fontSize multiply is the footgun. `showTvLongListPicker` is the in-repo TV picker ([Layer 1]).
5. TODOS.md: live peek PR2 unrelated, not blocking. Eng auto-wrote Slice 1 follow-ups (CV-016, resume+sleep P2; EPG/UA/backup/caption style/ads P3).
6. Completeness: add TV overflow test, double-scale assertion, captions apply-gate test, privacy constructor tests. Not a shortcut packet after Eng locks.
7. Distribution: no new artifact. Existing Aika Stream APK. N/A.

No User Challenge. Native did not reverse Slice 1.

#### Section 1 Architecture

```
iptvSettingsSections (feature_iptv_core)
        |
        +-- TvSettingsScreen (app, iterates TV-visible)
        |     Theme -> Accessibility -> Playback -> Country -> Sources -> Privacy -> About
        |       AccessibilitySettingsSection(forTv: true)   [new]
        |       CountrySettingsTile(forTv: true)            [widen]
        |         -> showTvLongListPicker (existing)
        |       TvPrivacySection(showTelemetry, deleteFirst)[widen]
        |
        +-- SettingsHubScreen (app, HARDCODED — do not iterate TV-visible set)
              mobile: Appearance, Audio, Playback, Country, Playlist, EPG, +Accessibility
              compact ShellId.tv: minus Audio, +Privacy inject

ChannelLibraryGrid (feature_iptv, already StatefulWidget)
  promote ConsumerStatefulWidget; watch tvFontModeProvider ONCE
  MediaQuery textScaler(baseScale * fontMode.scale) around ALL card branches
  TV rowExtent grows when scale > 1  (_cardHeight is 169 today)

captionPreferenceProvider --> Settings Off/On only
  _applyCaptionPreferenceIfNeeded UNCHANGED
  (enabled && languageCode != null) else return
```

Coupling: app composes feature_iptv widgets (existing). Privacy stays in app next to `aikaStreamLocalDataDeleterProvider`. No new network. Rollback: git revert; prefs keys already exist.

[P1] (confidence: 9/10) `channel_library_grid.dart:975-989` — per-tile MediaQuery already applies `baseScale * fontMode.scale`. Task 3 also multiplying local `fontSize` double-scales. Quote: `textScaler: TextScaler.linear(baseScale * fontMode.scale)`. Auto-fix: one seam.

[P1] (confidence: 9/10) `channel_library_grid.dart:25` — `_cardHeight = 169.0` is the overflow floor at scale 1. Extra large grows text; sliver extent does not. Auto-fix: grow TV `rowExtent` when scale > 1.

[P2] (confidence: 9/10) `filter_dialogs.dart:203-208` — `FilterOptionDialog` "does not scale to a full-size country list". Auto-fix: TV uses `showTvLongListPicker`. Taste vs DX lock; Eng wins (P4 DRY). Surfaced at gate.

[P2] (confidence: 9/10) `settings_hub_screen.dart:88-91` — comment claims SSOT; tiles are hardcoded and always `ShellId.mobile` labels. Auto-fix: comment + keep hardcoded.

[P2] (confidence: 9/10) `tv_privacy_section.dart:11-33` — no `showTelemetry`/`deleteFirst`; first consent row `autofocus: true`. Compact hub with telemetry hidden must not autofocus a missing widget.

Production failure: Extra large on Fire TV Library → yellow/black overflow stripes. Plan now accounts via rowExtent + `takeException() == null`.

Distribution architecture: N/A (existing app).

#### Section 2 Code quality

[P2] (confidence: 9/10) `country_settings_tile.dart:14-15` — no `forTv`; `enabled: canPickCountry` drops D-pad focus. Auto-fix: focusable no-op when empty.

[P2] (confidence: 8/10) Phone Accessibility `Column` overflows captions copy. Auto-fix: `ListView` + AppBar title `Accessibility`.

[P3] (confidence: 7/10) `forTv: true` first-row autofocus can steal rail focus (same as `TvPlaybackSection`). Accept the Playback pattern. Do not mix.

DRY: do not fork a third country picker. Do not add `fontSize` to `MediaCard`. Hub must not start iterating the TV-visible set.

Examined existing ASCII comments on `_cardHeight` (lines 14–24): still accurate at scale 1; Eng task must update the comment when rowExtent becomes scale-dependent.

#### Section 3 Test review

Framework: Flutter `flutter test` (workspace CLAUDE.md / package tests). RUNTIME:dart.

```
CODE PATHS                                              USER FLOWS
[+] iptv_settings_manifest.dart                         [+] TV Settings rail
  ├── accessibility id + order                            ├── [GAP] Theme→Accessibility→…→About
  └── country visibleFor TV                               ├── [GAP] invert Accessibility findsNothing
[+] accessibility_settings_section.dart                 [+] Font Large persist
  ├── [GAP] Large writes tv_font_mode=large               ├── [GAP] Library names larger, chrome unchanged
  ├── [GAP] captions Off/On + copy                        └── [GAP] Extra large TV-width no overflow
  └── [GAP] forTv: true has no Switch                   [+] Captions
[+] channel_library_grid.dart                             ├── [GAP] On + eng would select
  ├── [GAP] one scaler; ratio ~1.5 not 2.25               └── [GAP] On + null language no-op
  ├── [GAP] TV rowExtent when scale>1                   [+] Country TV
  └── [GAP] ProviderScope on every existing pump          ├── [GAP] showTvLongListPicker
[+] TvPrivacySection                                      └── [GAP] empty row focusable, picker closed
  ├── [GAP] showTelemetry:false mounts no consent       [+] Privacy compact hub
  └── [GAP] confirm autofocus Cancel                      ├── [GAP] Delete first; Cancel focused
[+] TvPlaybackSection                                     └── [GAP] super-app has no Privacy
  └── [GAP] ChannelGridDensitySection findsNothing      [+] Audio
                                                          └── [GAP] ShellId.tv hub has no Audio Settings

LLM integration: none. Eval: n/a
COVERAGE (planned after Eng): 0/18 paths in tree today for new Settings surfaces
QUALITY: existing privacy delete ★★; Library overflow tests exist at scale 1 only
GAPS: 14 (0 E2E required this packet — widget tests cover D-pad chrome; Fire TV qualify is manual)
```

REGRESSION: `tv_settings_screen_test.dart:42` expects no Accessibility because Coming-soon was a D-pad dead end. Adding the section without inverting that test is a **CRITICAL** regression of the test, not of product. Invert it.

Test plan artifact: `~/.gstack/projects/DevelopersCoffee-airo/udaychauhan-agent-iptv-aika-stream-002-21-eng-review-test-plan-20260923-010128.md`

#### Section 4 Performance

[P2] (confidence: 8/10) Per-tile `Consumer` + try/catch on every Library cell. Promote grid-level watch (native finding). No N+1. TextScaler wrap is cheap vs extra isolate. Prefs reads already cached by Riverpod.

No caching work this packet. Slow path: Extra large overflow is a layout bug, not a perf bug.

#### NOT in scope (Eng)

- CV-013 PIN / household profiles
- Ads opt-out, Smart Audio on TV, surf, cloud sync, TV backup, decoder/buffer/external player
- Rewriting prefs notifiers to surface save failures
- `core_ui` MediaCard / ThemeData rewrite
- Changing `_applyCaptionPreferenceIfNeeded`
- Iterating `iptvSettingsSections` on `SettingsHubScreen`
- ICAST bumps (`airo_epg` / `airo_ads` stay follow-ups)
- Council review loop as an implementation gate (record only)

#### What already exists (Eng)

- Library MediaQuery wrap (`_ChannelTile` 975–989) — reuse, do not add a second multiply
- `tv_channel_grid.dart` multiplies `fontSize` by `textScaleFactor * fontScale` — do not copy that onto cards already under MediaQuery
- `showTvLongListPicker` — TV country
- `showFilterOptionDialog` — phone country
- `TvPrivacySection` delete + telemetry — widen constructor
- Compact hub Audio wrap already in `4120f32f` for `shellId == ShellId.mobile` — keep; still add Accessibility + Privacy

#### Failure modes

| Path | Failure | Test | Handling | User sees | Critical? |
| --- | --- | --- | --- | --- | --- |
| Extra large TV Library | RenderFlex overflow | Eng: TV-width takeException | grow rowExtent | yellow stripes | **critical gap until Task 3 rewrite** |
| Dual scale | names 2.25× | ratio ~1.5 | one seam | unreadable tiles | **critical gap until Task 3 rewrite** |
| Captions On, no language | silent no-op | apply-gate test | existing return | copy already honest | covered after Eng test |
| Country empty on TV | unfocusable / empty dialog | focusable no-op | keep row | stuck D-pad | covered after Eng |
| Privacy compact + hidden telemetry | autofocus missing widget | privacy test | skip consent rows | focus dump | covered after Eng |
| Prefs write fail | UI On, disk Off | none (existing) | swallow | restart reverts | accepted DX P3, not critical (known) |
| Delete confirm | accidental wipe | Cancel autofocus | dialog | data gone if OK | covered |

Critical gaps: 2 until Task 3 rewrite lands in the plan (rowExtent + single scale). After amend: 0 remaining unplanned.

#### Parallelization

| Step | Modules touched | Depends on |
|------|----------------|------------|
| Manifest accessibility + country visible | feature_iptv_core | — |
| Accessibility widget | feature_iptv/settings | Manifest id |
| Library single scale + rowExtent | feature_iptv/tv_ux | — |
| Country forTv + long list | feature_iptv/settings | — |
| Privacy constructor | app/settings/tv | — |
| TV rail switch | app/settings/tv | Manifest + widgets |
| Hub tiles | app/settings/hub | widgets |

Lane A: Library scale (feature_iptv/tv_ux) — independent
Lane B: Manifest → Accessibility widget → Country forTv (feature_iptv settings + core)
Lane C: Privacy constructor (app/tv) — independent of Library
Then Lane D: rail + hub (app) after B+C.

Conflict: Lanes B and D both touch settings tests; merge B then D. Do not parallelize hub and rail in two worktrees (same `app/lib/features/settings`).

Sequential implementation for app/ settings; Library lane can run in parallel.

#### Diagrams in code

Update the `_cardHeight` comment in `channel_library_grid.dart` when rowExtent becomes scale-dependent. No new service pipeline comments.

#### Completion summary

- Step 0: Scope Challenge — scope accepted as-is (never reduce); seams rewritten
- Architecture Review: 5 issues found (2 P1 auto-fixed, 3 P2 auto-fixed)
- Code Quality Review: 3 issues found (auto-fixed)
- Test Review: diagram produced, 14 gaps identified (all added to tasks)
- Performance Review: 1 issue found (grid-level watch)
- NOT in scope: written
- What already exists: written
- TODOS.md updates: 7 items auto-written (2 P2, 5 P3)
- Failure modes: 2 critical gaps flagged, both folded into Task 3
- Outside voice: ran native; Codex unavailable
- Parallelization: 3 lanes, Library parallel / app settings sequential
- Lake Score: 3/3 recommendations chose complete option (rowExtent, apply-gate test, privacy tests)
- Unresolved decisions: 1 taste (TV country picker: Eng `showTvLongListPicker` vs DX `showFilterOptionDialog`) — queued for Final Gate

<!-- autoplan-baseline-edits:eng {"sourceSha256":"348cc21b01d6b3d8bdb0367d427d5e1d531bc4bddfba1574894371150d0f0ad6","replacements":[{"oldText":"| Country | Reuse `CountrySettingsTile({bool forTv = false})`. TV wraps the same `showFilterOptionDialog` in `TvFocusable`. Empty country list stays focusable with existing subtitle. Do not fork the picker |","newText":"| Country | Reuse `CountrySettingsTile({bool forTv = false})`. TV: `TvFocusable` + existing `showTvLongListPicker`. Phone keeps `showFilterOptionDialog`. Empty list stays focusable; onSelect no-op. Do not invent a third picker |"},{"oldText":"- `tvFontModeProvider` applied in `tv_channel_grid.dart` only. Live Aika Stream browse is `ChannelLibraryGrid`, which does not watch the scale today.","newText":"- `tvFontModeProvider` applied in `tv_channel_grid.dart` (multiplies fontSize) and already in live `ChannelLibraryGrid` (`_ChannelTile` wraps each card in MediaQuery textScaler `baseScale * fontMode.scale`, commit `4120f32f`). Do not add a second scale multiply."},{"oldText":"Phone is a `Column`/`ListView` with a Switch for captions. Do not invent a dual anonymous layout.","newText":"Phone is a `ListView` (not a Column — captions copy overflows small phones) with a Switch for captions. Pushed hub route uses AppBar title `Accessibility`. Do not invent a dual anonymous layout."},{"oldText":"- [ ] Watch `tvFontModeProvider` in `ChannelLibraryGrid` (promote to `ConsumerStatefulWidget` if needed). Named seam: wrap the `MediaCard` branch in `MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), ...)`. Local `_CompactGridMediaCard` / `_HorizontalMediaCard` multiply their hardcoded `fontSize` by `TvFontMode.scale`. Do not add a `fontSize` parameter to `MediaCard` / `AiroRailCard`. Do not rewrite `core_ui` `ThemeData`. Do not scale Settings chrome.\n- [ ] Widget test: Extra large enlarges Library names vs Standard. Existing overflow tests stay green; if Extra large overflows a dense phone tile, drop subtitle the same way `compactGridShowSubtitle` already does at 5-up — do not clip names.\n- [ ] Assert `TvPlaybackSection` does **not** contain `ChannelGridDensitySection`. Phone Playback keeps density.","newText":"- [ ] Promote `ChannelLibraryGrid` to `ConsumerStatefulWidget` and watch `tvFontModeProvider` once. Keep a single MediaQuery `textScaler: TextScaler.linear(baseScale * fontMode.scale)` around every card branch (MediaCard, compact, horizontal). Remove the per-tile Consumer + ProviderScope try/catch. Do **not** also multiply `_CompactGridMediaCard` / `_HorizontalMediaCard` `fontSize` by `TvFontMode.scale` (Flutter already applies textScaler; Extra large would become 2.25×). Do not add `fontSize` to `MediaCard` / `AiroRailCard`. Do not rewrite `core_ui` `ThemeData`. Do not scale Settings chrome.\n- [ ] When `fontMode.scale > 1`, grow TV `rowExtent` above `_cardHeight` (169) with the scaled text block, or drop subtitle on the MediaCard path. Phone 5-up already drops subtitle via `compactGridShowSubtitle`. Update the in-file `_cardHeight` comment.\n- [ ] Widget tests: Extra large vs Standard on a TV-width viewport (≥600) with `expect(tester.takeException(), isNull)`; Extra large name scale ratio close to 1.5 not 2.25; assert MediaCard path via laid-out height or `RenderParagraph.textScaler`, not `Text.style.fontSize`. Wrap every existing `channel_library_grid_test.dart` pump in `ProviderScope` + `sharedPreferencesProvider`.\n- [ ] Assert `TvPlaybackSection` does **not** contain `ChannelGridDensitySection` (`findsNothing` in `tv_playback_section_test.dart`). Phone Playback keeps density."},{"oldText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection(forTv: true)`; `country` → `CountrySettingsTile(forTv: true)` (add `forTv` + `TvFocusable` around the existing `showFilterOptionDialog`; when no countries, keep the row focusable with the existing subtitle). Remove those ids from the \"never selected\" shrink list.","newText":"- [ ] Switch cases: `accessibility` → `AccessibilitySettingsSection(forTv: true)`; `country` → `CountrySettingsTile(forTv: true)` (`TvFocusable` + existing `showTvLongListPicker`; when `!canPickCountry`, keep the row focusable and do not open a picker). Use `labelFor`/`iconFor` for `ShellId.tv` when `forTv`. Invert `tv_settings_screen_test` Accessibility `findsNothing`. Remove those ids from the \"never selected\" shrink list."},{"oldText":"- [ ] Add Accessibility tile immediately after Appearance (manifest labels) pushing a `Scaffold` that hosts `AccessibilitySettingsSection(forTv: false)`.","newText":"- [ ] Add Accessibility tile immediately after Appearance (manifest labels) pushing a `Scaffold` with AppBar title `Accessibility` that hosts `AccessibilitySettingsSection(forTv: false)` in a `ListView`. Comment: compact `ShellId.tv` hub is phone layout + opt-in Privacy; do not iterate the TV-visible manifest set."},{"oldText":"- [ ] `flutter test` the files named above plus `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart` and `app/test/features/settings/presentation/screens/settings_hub_screen_test.dart`. Do not run the full workspace matrix.","newText":"- [ ] `flutter test` the files named above plus `app/test/features/settings/presentation/tv/tv_settings_screen_test.dart`, `app/test/features/settings/presentation/screens/settings_hub_screen_test.dart`, and `app/test/features/settings/presentation/tv/tv_privacy_section_test.dart` (`showTelemetry: false`, `deleteFirst: true`, Cancel focused). Add a focused captions apply-gate test: enabled + null language does not select; enabled + `eng` would. Do not run the full workspace matrix."},{"oldText":"- `CountrySettingsTile` uses mobile `ListTile` / dialogs. Wrap with `TvFocusable` and existing `showFilterOptionDialog` rather than a new picker.\n- Privacy: do not probe `PlatformMediaLogger` (no `isBootstrapped`; default is already `AiroNoOpAnalyticsService`). Compact hub passes `showTelemetry: false`. Prefs notifiers keep swallowing save failures this packet (existing pattern); do not rewrite them.\n- Font scale today hits only `TvChannelGrid`, not live `ChannelLibraryGrid`. Slice 1 must apply scale to Library names. If Settings chrome does not scale, that is acceptable; do not rewrite `core_ui` text theme.","newText":"- `CountrySettingsTile` uses mobile `ListTile` / `showFilterOptionDialog`. TV `forTv: true` uses existing `showTvLongListPicker` (browse already does; FilterOptionDialog does not scale to a full country list). Empty country: focusable no-op.\n- Privacy: do not probe `PlatformMediaLogger` (no `isBootstrapped`; default is already `AiroNoOpAnalyticsService`). Compact hub passes `showTelemetry: false` and must not autofocus a missing consent row. Prefs notifiers keep swallowing save failures this packet; do not rewrite them.\n- Library already applies `tvFontMode` via per-tile MediaQuery. Slice 1 must collapse to one grid-level seam and grow TV rowExtent when scale > 1. If Settings chrome does not scale, that is acceptable; do not rewrite `core_ui` text theme."}]} -->
<!-- autoplan-accepted:eng -->
- Library scale: `_ChannelTile` already wraps cards in `MediaQuery` `textScaler: TextScaler.linear(baseScale * fontMode.scale)` (`channel_library_grid.dart` ~975-989). Promote `ChannelLibraryGrid` to `ConsumerStatefulWidget`, watch `tvFontModeProvider` once, one MediaQuery seam for every card branch. Do not multiply local `_CompactGridMediaCard` / `_HorizontalMediaCard` `fontSize` while those cards sit under that MediaQuery. Remove per-tile Consumer + try/catch.
  Verify: Extra large name ratio ~1.5 not 2.25; no MediaCard signature change; existing Library pumps use ProviderScope + sharedPreferencesProvider.
- TV Library overflow: `_cardHeight` is fixed 169. When `fontMode.scale > 1`, grow TV `rowExtent` with the scaled text block (or drop subtitle on the MediaCard path). Phone 5-up already drops subtitle via `compactGridShowSubtitle`.
  Verify: viewport width ≥600, Extra large vs Standard, `tester.takeException() == null`.
- TV country: `forTv: true` calls existing `showTvLongListPicker`. Phone keeps `showFilterOptionDialog`. No third picker. When `!canPickCountry`, row stays focusable; onSelect no-op. Use `labelFor`/`iconFor` for `ShellId.tv` when `forTv`.
  Verify: empty-country row present and focusable; picker does not open.
- `TvPrivacySection({bool showTelemetry = true, bool deleteFirst = false})`. If `!showTelemetry`, do not mount consent rows and do not autofocus a missing widget. Confirm: `TvFocusable(autofocus: true)` on Cancel only, both shells. Extend `tv_privacy_section_test.dart`. Do not call `PlatformMediaLogger` / `isBootstrapped`.
- Hub stays hardcoded. Comment: compact `ShellId.tv` hub is phone layout + opt-in Privacy; do not iterate TV-visible `iptvSettingsSections`. Accessibility push: AppBar title `Accessibility`; body `ListView`.
- Captions apply gate: keep `_applyCaptionPreferenceIfNeeded` unchanged. Add a focused test: enabled + `languageCode == null` does not select a track; enabled + `eng` would. Invert `tv_settings_screen_test` Accessibility `findsNothing`. Density: `find.byType(ChannelGridDensitySection), findsNothing` on TV Playback.
- Implementer SSOT is locked table + Tasks 1-6 as Eng-amended. CEO accepted recap ("stream default"; density on TV Playback) stays byte-for-byte but is superseded. DX TV `showFilterOptionDialog` is superseded by `showTvLongListPicker`.
<!-- /autoplan-accepted:eng -->

<!-- AUTONOMOUS DECISION LOG -->
## Decision Audit Trail

| # | Phase | Decision | Classification | Principle | Rationale | Rejected |
|---|-------|----------|-----------|-----------|----------|----------|
| 1 | CEO | SELECTIVE_EXPANSION | Mechanical | autoplan override | Feature enhancement default | EXPANSION / HOLD / REDUCTION |
| 2 | CEO | Approach A: surface existing providers | Mechanical | P1+P5 | Highest completeness of sofa win without new stores | B Playback-only, C first-run prompt |
| 3 | CEO | Privacy Aika Stream shells only | Mechanical | P5 | Locked decision already said this; Task 5 was too wide | Every IPTV hub |
| 4 | CEO | Captions on/off + honest copy | Mechanical | P5 | No language picker widget | Language list in Slice 1 |
| 5 | CEO | Keep Accessibility rail | Taste | P1 | Sofa discoverability vs phone grouping | Merge under Playback |
| 6 | CEO | Two P2 follow-ups, rest P3 | Taste | P3 | Avoid TODO graveyard | Eight equal TODOs |
| 7 | CEO | Skip Codex retry with guessed model | Mechanical | evidence | 400 on gpt-6-astra; do not guess | Silent model swap |
| 8 | Design | Apply tvFontMode to ChannelLibraryGrid | Mechanical | P1+P5 | Live Library is the sofa grid; TvChannelGrid is unused there | Settings-only placebo font |
| 9 | Design | Honest captions copy; keep player no-op | Mechanical | P5 | languageCode null does not select a track | "stream default" copy; changing apply path |
| 10 | Design | Drop density from TV Playback | Mechanical | P5 | phoneGridColumns ignored above 600px | CEO Task 3 mount on TV |
| 11 | Design | Rail Theme → Accessibility → Playback → Country → Sources → Privacy → About | Mechanical | P5 | Accessibility is the sofa job; Privacy last | Manifest insertion at end |
| 12 | Design | TV captions Off/On TvFocusable rows | Mechanical | APP UI | Fire TV Switch is not D-pad native | Material Switch on 10-foot |
| 13 | Design | Wrap Audio tile to ShellId.mobile | Mechanical | P5 | Compact hub already shows ducking | Hope it is already hidden |
| 14 | Design | Confirm autofocus Cancel | Mechanical | P5 | TV dialog today focuses Delete | Keep destructive default focus |
| 15 | Design | Skip Codex retry with guessed model | Mechanical | evidence | GSTACK_CODEX_MODEL unset; same 400 | Silent model swap |
| 16 | DX | DX POLISH + Flutter-engineer persona | Mechanical | autoplan override | In-repo widget packet, not public SDK | EXPANSION / TRIAGE |
| 17 | DX | MediaQuery textScaler around MediaCard | Mechanical | P5 | MediaCard has no fontSize; no core_ui API / ICAST | Add fontSize to AiroRailCard |
| 18 | DX | AccessibilitySettingsSection(forTv) | Mechanical | P5 | Playback already uses two layouts | Dual anonymous widget |
| 19 | DX | Privacy stays TV in manifest; hub special-case | Mechanical | P5 | Hub does not iterate iptvSettingsSections | Widen privacy for mobile |
| 20 | DX | TvPrivacySection(showTelemetry, deleteFirst) | Mechanical | P5 | No isBootstrapped on PlatformMediaLogger | Logger probe |
| 21 | DX | CountrySettingsTile(forTv) | Mechanical | P5 | Mobile ListTile is a D-pad trap | Fork picker |
| 22 | DX | Skip prefs-notifier rewrite | Taste | P3 | Existing swallow; CEO said not this packet | SnackBar on every save fail |
| 23 | DX | Copy-paste flutter test recipe | Mechanical | P1 | Implementer TTHW | Hope they find test files |
| 24 | DX | Skip Codex retry with guessed model | Mechanical | evidence | GSTACK_CODEX_MODEL unset | Silent model swap |
| 25 | Eng | Never reduce Slice 1 despite 8+ files | Mechanical | P2 autoplan override | Sofa packet needs Accessibility+country+privacy | Drop country or privacy |
| 26 | Eng | One Library MediaQuery seam; no fontSize multiply | Mechanical | P5 | Library already scales; dual multiply is 2.25× | DX second multiply on local cards |
| 27 | Eng | Grow TV rowExtent when scale > 1 | Mechanical | P1 | _cardHeight 169 overflows Extra large | Phone-only subtitle drop |
| 28 | Eng | TV country uses showTvLongListPicker | Taste | P4+P5 | FilterOptionDialog comment says it does not scale | Keep DX showFilterOptionDialog |
| 29 | Eng | Hub stays hardcoded; fix the SSOT comment | Mechanical | P5 | Iterating TV-visible set would show Sources, hide EPG | Drive hub from manifest |
| 30 | Eng | Privacy constructor + Cancel focus tests | Mechanical | P1 | Missing autofocus target when telemetry hidden | Hub test only |
| 31 | Eng | Captions apply-gate unit test; player unchanged | Mechanical | P1 | Widget Switch cannot catch apply-path edits | Change _applyCaptionPreferenceIfNeeded |
| 32 | Eng | Invert Accessibility findsNothing | Mechanical | regression rule | Coming-soon dead-end test would fail the real section | Leave findsNothing |
| 33 | Eng | Grid-level tvFontMode watch vs per-tile Consumer | Mechanical | P3+P5 | Per-tile try/catch is accidental complexity | Keep per-tile wrap |
| 34 | Eng | Skip Codex retry with guessed model | Mechanical | evidence | Same 400 as prior phases | Silent model swap |

## Implementation Tasks

Synthesized from this review's findings.

- [ ] **T1 (P1, human: ~1h / CC: ~10min)** — Settings — Restate Privacy to Aika Stream shells only; negative test on super-app hub
  - Surfaced by: CEO dual voice Finding 2
  - Files: `settings_hub_screen.dart`, `settings_hub_screen_test.dart`
  - Verify: super-app hub has no Delete local data
- [ ] **T2 (P1, human: ~1h / CC: ~10min)** — Accessibility — Captions on/off copy; font grid disclaimer
  - Surfaced by: CEO Findings 3–4
  - Files: `accessibility_settings_section.dart`
  - Verify: no language picker; copy present
- [ ] **T3 (superseded)** — Playback — D-pad-safe density on TV
  - Surfaced by: CEO Section 2 GAP; **struck by Design D3** — density is phone-only
  - Files: do not mount on `tv_playback_section.dart`
  - Verify: TV Playback has no density radios
- [ ] **D1 (P1, human: ~1h / CC: ~15min)** — Library — Apply `tvFontMode` scale to `ChannelLibraryGrid` names
  - Surfaced by: Design Pass 1/6; native UX officer
  - Files: `channel_library_grid.dart`, `channel_library_grid_test.dart`
  - Verify: Extra large enlarges Library names; Settings chrome unchanged
- [ ] **D2 (P1, human: ~45min / CC: ~10min)** — Accessibility — Captions Off/On rows + honest copy + language status
  - Surfaced by: Design Pass 2/4
  - Files: `accessibility_settings_section.dart`
  - Verify: no "stream default"; null language shows status; no Switch on TV
- [ ] **D3 (P1, human: ~20min / CC: ~8min)** — Playback — Do not mount density on TV; assert absence
  - Surfaced by: Design Pass 1
  - Files: `tv_playback_section.dart` tests only
  - Verify: no `ChannelGridDensitySection` in TV Playback
- [ ] **D4 (P1, human: ~30min / CC: ~10min)** — TV rail — Manifest order Theme → Accessibility → Playback → Country → Sources → Privacy
  - Surfaced by: Design Pass 1
  - Files: `iptv_settings_manifest.dart`, `tv_settings_screen_test.dart`
  - Verify: rail order widget test
- [ ] **D5 (P1, human: ~20min / CC: ~8min)** — Hub — Hide Audio on `ShellId.tv`
  - Surfaced by: Design Pass 6
  - Files: `settings_hub_screen.dart`, `settings_hub_screen_test.dart`
  - Verify: compact hub has no Audio Settings tile
- [ ] **D6 (P1, human: ~20min / CC: ~8min)** — Privacy — Phone Delete-first; confirm autofocus Cancel
  - Surfaced by: Design Pass 2
  - Files: `tv_privacy_section.dart`, phone extract, tests
  - Verify: initial focus Cancel; telemetry hidden without logger
- [ ] **T4 (P2, human: ~2d / CC: ~1h)** — Follow-up — Preferred audio/caption language (CV-016)
  - Surfaced by: CEO Finding 5
  - Files: player + settings
  - Verify: language persists across streams
- [ ] **T5 (P2, human: ~2d / CC: ~1h)** — Follow-up — Resume last channel + sleep timer on TV binary
  - Surfaced by: CEO Finding 7
  - Files: `main_tv.dart`, Watch route, `sleepTimerProvider`
  - Verify: cold start tunes last live channel; sleep stops Watch
- [ ] **X1 (P1, human: ~30min / CC: ~10min)** — Accessibility — `forTv` constructor; tests under `test/iptv/presentation/`
  - Surfaced by: DX 2c
  - Files: `accessibility_settings_section.dart`, `feature_iptv.dart`
  - Verify: TV has no Switch; export exists
- [ ] **X2 (P1, human: ~45min / CC: ~12min)** — Library — MediaQuery textScaler around MediaCard; local cards multiply fontSize
  - Surfaced by: DX 2b
  - Files: `channel_library_grid.dart`
  - Verify: no MediaCard API change; Extra large enlarges names
- [ ] **X3 (P1, human: ~30min / CC: ~10min)** — Country — `forTv` + TvFocusable; empty list stays focusable
  - Surfaced by: DX 2e
  - Files: `country_settings_tile.dart`
  - Verify: same showFilterOptionDialog
- [ ] **X4 (P1, human: ~30min / CC: ~10min)** — Privacy — `showTelemetry`/`deleteFirst`; privacy stays TV in manifest
  - Surfaced by: DX 2d/2f
  - Files: `tv_privacy_section.dart`, `iptv_settings_manifest.dart`, hub
  - Verify: super-app no Privacy; compact hub Delete-first
- [ ] **X5 (P1, human: ~15min / CC: ~5min)** — Tests — copy-paste Task 6 recipe + languageCode eng override
  - Surfaced by: DX Pass 1
  - Files: Accessibility widget test
  - Verify: recipe command listed in plan Task 6
- [ ] **E1 (P1, human: ~45min / CC: ~15min)** — Library — Single MediaQuery seam; no local fontSize multiply
  - Surfaced by: Eng Architecture — `_ChannelTile` already wraps (`channel_library_grid.dart:975-989`)
  - Files: `channel_library_grid.dart`, `channel_library_grid_test.dart`
  - Verify: Extra large ratio ~1.5 not 2.25; ProviderScope on every pump
- [ ] **E2 (P1, human: ~30min / CC: ~10min)** — Library — Grow TV rowExtent when scale > 1
  - Surfaced by: Eng Architecture — `_cardHeight = 169` overflow
  - Files: `channel_library_grid.dart`
  - Verify: TV-width Extra large `takeException() == null`
- [ ] **E3 (P1, human: ~30min / CC: ~10min)** — Country — TV `showTvLongListPicker`; empty row focusable no-op
  - Surfaced by: Eng Architecture — `filter_dialogs.dart:203-208`
  - Files: `country_settings_tile.dart`, `tv_settings_screen.dart`
  - Verify: picker does not open when empty; Fire TV long list opens when countries exist
- [ ] **E4 (P1, human: ~20min / CC: ~8min)** — Privacy — `showTelemetry`/`deleteFirst`; no autofocus on missing row
  - Surfaced by: Eng Architecture — `tv_privacy_section.dart:11-33`
  - Files: `tv_privacy_section.dart`, `tv_privacy_section_test.dart`
  - Verify: compact flags; Cancel focused
- [ ] **E5 (P1, human: ~15min / CC: ~5min)** — Hub — AppBar Accessibility; ListView; hardcoded-hub comment
  - Surfaced by: Eng Code quality
  - Files: `settings_hub_screen.dart`
  - Verify: small-phone captions copy does not overflow
- [ ] **E6 (P1, human: ~20min / CC: ~8min)** — Captions — apply-gate test; invert Accessibility findsNothing; density findsNothing
  - Surfaced by: Eng Test review
  - Files: captions test, `tv_settings_screen_test.dart`, `tv_playback_section_test.dart`
  - Verify: null language does not select; rail shows Accessibility
