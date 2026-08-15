# Milestone 11 — v2.0.1 Public Release & Store Publishing — remaining work prompt

Paste this as-is to drive milestone 11 to completion.

---

Repo: DevelopersCoffee/airo. Milestone 11 "v2.0.1 — Public Release & Store Publishing", epic #674. **Strategy update (2026-08-13): v2 branch/tag dropped. Base branch for every child issue is `main`, release line is `0.0.7-preview`** — `git fetch origin main` and start from latest `origin/main` before writing any code. No application feature work belongs in this epic — release orchestration only.

11 open issues: #576 #673 #674 #682 #683 #687 #689 #716 #756 #803 #1065.

**Step 0 — credential/secret blockers, cannot proceed without user action, surface these immediately and wait:**
- #576 Android signing secrets for Airo TV internal release — need keystore + signing config from user
- #756 Firebase Android clients for v2 mobile/tablet package IDs — need Firebase project access/app registration from user
- #803 Sign and notarize Airo TV for public consumer release (macOS) — need Apple Developer ID cert + notarization credentials from user

Do not attempt to fabricate, generate, or guess at any of these three — they are explicitly user-owned per the epic's "User Intervention Needed" section (final release tag format, supported channels, signing keystore, Play service account, Firebase app IDs, Play package IDs, tester groups are all open questions the epic flags as user-confirm-required). Ask, then park these three until answered; work everything else in the meantime.

**Step 1 — pure engineering, no external creds needed, start immediately, can run in parallel:**
- #689 complete repository health gates for public release readiness
- #687 add LICENSE + third-party license review before public distribution
- #683 add release qualification matrix for mobile, tablet, and TV artifacts (defines what "verified" means before Step 2 needs it)

**Step 2 — depends on Step 0 credentials landing:**
- #682 upload v2 APKs to Firebase App Distribution for internal testing — needs #756 done first
- #716 iPad Air UI/UX Device Qualification & Responsive Layout Testing Campaign — needs a signed, distributable build to test against (needs #576/#756)

**Step 3 — hygiene, do anytime, low risk, don't block on it:**
- #673 triage dirty local Airo worktrees before workspace cleanup
- #1065 triage recent-development local branches and dirty worktrees before cleanup

**Step 4 — close the loop:**
- #674 epic itself — update its checklist as child issues close; do not close the epic until all children (including the pre-existing related issues it references: #563 #585 #581 #574 #647 #657 #294) are either done or explicitly deferred with a note

Rules for every PR in this milestone:
- Base off `origin/main`, PR target is `main`
- Reviewing agents per the epic gate: Security and Privacy Agent, QA Automation Agent, Mobile UI Agent, Media Agent — route review accordingly (use chief-security-officer / chief-qa-officer / flutter-architect agents as the closest match in this repo's agent roster)
- Impacted paths: `.github/workflows`, `app`, `packages`, `docs/release`, release scripts — narrowest CI job per CLAUDE.md GH-minutes policy
- Never commit or paste actual signing keys/secrets into the repo or into chat — GitHub Actions secrets only, entered by the user directly in repo settings
- No feature work rides along in any PR here

Report progress against this list after each issue lands. If Step 0 answers don't arrive, keep working Step 1 and report status rather than stalling.
