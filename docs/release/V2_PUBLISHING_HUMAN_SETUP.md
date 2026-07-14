# V2 Publishing Human Setup Checklist

This checklist tracks release tasks that cannot be completed by CI or agents
alone because they require account ownership, store-console access, secrets, or
maintainer decisions.

Use this alongside the v2 distribution matrix before enabling real publishing
jobs. Automation may support dry-run mode before these items are complete, but
production publishing cannot be verified without them.

## Google Play

Related issues: #681, #585, #657.

- [ ] Create or confirm the Play Console app for each public v2 package ID.
- [x] Confirm package IDs for mobile/tablet and TV:
      `io.airo.app`, `io.airo.app.iptv`, `io.airo.app.streaming`, and
      `io.airo.app.tv`.
- [ ] Decide whether mobile and tablet share one adaptive listing or use
      separate listings.
- [ ] Create a Play service account for release automation.
- [ ] Grant the service account release permissions for the target apps.
- [ ] Store the service account JSON as a GitHub Actions secret.
- [ ] Confirm the first upload track for each app: internal, alpha, beta,
      production, or no-upload.
- [ ] Confirm whether TV uses the same Play app with device targeting or a
      separate Android TV listing.

## Firebase App Distribution

Related issues: #682, #574.

- [ ] Create or confirm Firebase apps for each package ID that should receive
      internal APKs.
- [ ] Add or confirm Firebase Android client configs for the registered
      `io.airo.app.*` packages that should use Firebase services.
- [ ] Create a Firebase service account or distribution token for CI.
- [ ] Store the Firebase credential as a GitHub Actions secret.
- [ ] Create tester groups for mobile/tablet QA and TV QA.
- [ ] Confirm whether TV APK distribution through Firebase is part of this
      release wave.

## Android Signing

Related issues: #677, #678, #681.

- [ ] Confirm the production Android keystore owner.
- [ ] Store the keystore as a base64 GitHub Actions secret.
- [ ] Store keystore password, key alias, and key password as GitHub Actions
      secrets.
- [ ] Confirm whether internal QA uses production signing or a release-candidate
      signing key.
- [ ] Confirm key backup and rotation ownership outside the repository.

## Distribution Channels

Related issues: #675, #685, #647, #657.

- [ ] Decide whether the first v2 release wave includes GitHub Releases only,
      Google Play, Firebase App Distribution, Amazon Appstore, F-Droid, or a
      subset.
- [ ] Confirm whether Fire TV is supported, compatible, experimental, or
      deferred for the first release.
- [ ] Confirm whether legacy Android TV boxes are supported, compatible,
      experimental, or unsupported.
- [ ] Confirm whether direct APK install is officially supported for every
      published profile or only for selected profiles.

## Repository Governance

Related issues: #687, #689.

- [x] Choose the root project license.
- [x] Add the root `LICENSE` after the license is chosen.
- [ ] Confirm whether any private or commercial dependencies are bundled in v2
      release profiles.
- [ ] Resolve the open items in
      [V2 License Review](./V2_LICENSE_REVIEW.md).
- [ ] Decide whether GitHub Discussions should be enabled for public support.
- [ ] Confirm CODEOWNERS entries for release, security, docs, v2 platform, and
      app/profile ownership.
- [ ] Confirm whether funding/sponsor configuration is intentionally absent.

## Current Non-Secret Defaults

- v2 implementation starts from latest `origin/v2`.
- GitHub Release direct-download APKs publish `SHA256SUMS` and a combined
  release manifest through the v2 orchestrator.
- Public release docs must avoid exposing playlist URLs, credentials, local
  network addresses, or private user data.
- Store uploads should support dry-run/no-upload mode until credentials and
  tracks are confirmed.
