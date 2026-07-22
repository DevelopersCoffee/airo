# Airo TV UX Phase 3 — Remote Overlay Plan

> Issue #1039. Base: `origin/main` at `d46dbade`.

1. Write failing pure-unit tests for random selection from the filtered list,
   including empty and single-item inputs; implement the deterministic helper.
2. Write failing widget tests for visible touch controls, inactivity dismissal,
   pointer reappearance, and one callback per touch control; implement the
   overlay without changing playback or failover behavior.
3. Write failing remote-input tests using existing TV focus/key patterns;
   wire channel navigation and mute/volume to established providers, with no
   drawn touch controls on D-pad surfaces.
4. Compose the overlay into `AiroTvShell`, giving random a D-pad focus target.
5. Run focused tests per slice, full feature-package tests/analyzer, review,
   and device dogfood before opening the PR.
