# Todo: #1462 — Foldable crease rule

- [x] Task 1 — `FoldPosture`/`FoldInfo`/`AiroFold` helper (relocated to `packages/core_ui/lib/src/adaptive/airo_fold.dart` — see plan deviation note in PR)
- [x] Task 2 — widget test for the helper (`packages/core_ui/test/airo_fold_test.dart`)
- [x] Checkpoint: helper test green
- [x] Task 3 — wire fold check into `_usesCompactInlinePlayer` (`video_player_widget.dart`)
- [x] Task 4 — consumer widget test, red before task 3 / green after (`video_player_widget_fold_test.dart`)
- [x] Checkpoint: full `feature_iptv` test suite green (867/867)
- [x] Task 5 — docs: stale core_ui reference fix + new "Foldable / crease rule" section in `RESPONSIVE_STANDARDS.md`
- [x] Checkpoint: `flutter analyze` on all touched files — no issues
- [ ] Commit + push + PR referencing #1462
