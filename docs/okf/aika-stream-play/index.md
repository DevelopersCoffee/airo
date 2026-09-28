---
okf_version: "0.2"
---

# Aika Stream Play ship

OKF v0.2 bundle for shipping `com.developerscoffee.tv.midas` (Aika Stream,
TV flavor) to Google Play. Lived process from Internal 21 through Production
**0.0.3+25** (2026-09-28). Format: [Open Knowledge Format](https://github.com/GoogleCloudPlatform/open-knowledge-format).

Load this index, then the playbook. Do not fork the process into a second
always-on rules file — `AGENTS.md` points here when relevant.

# Rules

* [Never reuse a Play versionCode](rules/never-reuse-play-versioncode.md) - Play consumes a code even if the AAB is later removed from a draft.
* [Production keystore only](rules/production-keystore-only.md) - validation-key AABs are not uploadable to this listing.

# Playbooks

* [Ship a Play drop](playbooks/shipping-play-drop.md) - version bump, signed AAB, human upload, Internal then Production.
* [Internal then Production](playbooks/internal-then-production.md) - Console clicks, review vs live, do not re-upload a live code.
* [Cut the release branch](playbooks/cut-release-branch.md) - `release/aika-stream-v{versionName}` from the SHA that built the live OBB.

# References

* [Version SSOT](references/version-ssot.md) - `app/pubspec_tv.yaml` plus `scripts/aika_stream_version.sh --sync-stub`.
