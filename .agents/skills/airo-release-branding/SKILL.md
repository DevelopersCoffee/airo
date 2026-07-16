---
name: airo-release-branding
description: Refresh Airo public branding, GitHub Pages content, device guides, screenshots, release links, and public roadmap from verified release evidence. Use for every Airo or Airo TV release, public website refresh, tutorial update, community-voice summary, or approved Airo TV Pro capability announcement.
---

# Airo Release Branding

Keep the public Airo story current without turning private work or roadmap ideas
into shipped-product claims.

## Workflow

1. Read `AGENTS.md`, the linked implementation issue, and the release-line
   policy before editing.
2. Fetch the release base and confirm the task branch contains the latest
   `origin/v2` for Airo TV work.
3. Collect evidence from these public sources:
   - latest Airo TV GitHub release and known limitations;
   - `docs/release/AIRO_TV_FEATURE_MATRIX.md`;
   - `docs/release/V2_DISTRIBUTION_MATRIX.md`;
   - `docs/release/V2_RELEASE_QUALIFICATION.md`;
   - open public milestones and `community-voice` issues.
4. If Airo TV Pro is in scope, read it only as a private research input. Apply the
   disclosure policy in `references/publication-policy.md` before using any
   finding.
5. Classify every claim as `Available`, `Under qualification`, `Private
   validation`, `Planned`, `Deferred`, or `Not adopted`. Never infer
   `Available` from merged code alone.
6. Update the page contract:
   - preserve Airo as the modular super-app umbrella;
   - present Airo TV as the active modular product;
   - keep download, device, guide, Community Voice, roadmap, trust, and legal
     sections current;
   - translate issue titles into customer problems while retaining public
     issue links.
7. Use real or sanitized Airo screenshots. Remove private URLs, credentials,
   third-party broadcast frames, unlicensed logos, and personal data.
8. For an approved live demo, require an explicit user gesture before any
   manifest request, identify the third-party source and network/privacy
   boundary, provide unavailable and unsupported states, and destroy playback
   on page exit. Never proxy, cache, rebroadcast, or silently preload it.
9. Update device tutorials only for behavior supported by the claim state.
10. Run the deterministic audit:

   ```bash
   python3 .agents/skills/airo-release-branding/scripts/audit_public_page.py
   ```

11. Serve `docs/`, test keyboard navigation and responsive layouts, and capture
    evidence at `1920x1080`, `1280x720`, `1024x576`, and `390x844`.
12. Report which claims changed, which remained planned, and which private
    findings were withheld. Do not publish, tag, or deploy unless the user
    explicitly requests it.

## Release Gate

Stop publication when the release tag is stale, device status conflicts with
the matrices, a private capability lacks approval, a screenshot has unclear
rights, a live demo preloads or lacks source disclosure, or the page audit
fails.
