# RC Signing Key Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make non-production-signed (`production_signing=false`) Android TV release builds share the same signing certificate across CI runs, so RC-to-RC updates on a real device (Pixel 9, 2026-07-20 finding) stop failing with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

**Architecture:** `.github/workflows/airo-tv-release.yml`'s "Configure Android signing" step (line 340-380) calls `keytool -genkeypair` fresh on every run when `production_signing=false`. Even with a fixed alias/password/DN, `keytool -genkeypair` generates new random RSA key material every invocation, so the resulting cert's public key (and therefore Android's package-signature identity) differs release to release. Fix: cache the generated `ci-validation.keystore` across workflow runs using `actions/cache` with a stable key, so the keystore is generated once and reused thereafter — first run creates it, every later run restores the same file instead of regenerating.

**Tech Stack:** GitHub Actions (`actions/cache@v6`, matching the version already used elsewhere in this workflow), bash, `keytool`.

## Global Constraints

- No new GitHub secrets — this fix must not require adding `ANDROID_RELEASE_KEYSTORE_BASE64`-style secrets, since `production_signing=false` builds are explicitly *not* meant to hold real signing credentials.
- Keep `production_signing=true` path (real secrets, real keystore) completely untouched.
- Worktree: `.claude/worktrees/rc-signing-key-stability`, branch `worktree-rc-signing-key-stability`.

---

### Task 1: Cache the CI-validation keystore across workflow runs

**Files:**
- Modify: `.github/workflows/airo-tv-release.yml:340-380` (the "Configure Android signing" step)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: a stable `app/android/ci-validation.keystore` + `app/android/key.properties` pair reused across every non-production-signed run, consumed implicitly by the existing downstream Gradle build steps (unchanged).

- [ ] **Step 1: Read the current step in full**

Run: `sed -n '340,382p' .github/workflows/airo-tv-release.yml`
Confirm the step name is exactly `Configure Android signing` and the `else` branch (non-production path) is the block calling `keytool -genkeypair` at what is currently line ~366.

- [ ] **Step 2: Insert a cache step before "Configure Android signing"**

Add a new step immediately before the existing `- name: Configure Android signing` step (same indentation level, i.e. inside the same job):

```yaml
      - name: Cache CI-validation Android keystore
        if: ${{ inputs.production_signing != true && github.event.inputs.production_signing != 'true' }}
        uses: actions/cache@v6
        with:
          path: |
            app/android/ci-validation.keystore
            app/android/key.properties
          key: airo-tv-ci-validation-keystore-v1
```

Use a fixed `key` with no hash inputs (`v1` suffix only, bump to `v2` if the keystore is ever intentionally rotated) — this is deliberate: the whole point is that the cache key never changes, so every run restores the same keystore instead of generating a new one.

- [ ] **Step 3: Make the signing step skip regeneration when the cache already restored the files**

Modify the non-production branch of the existing step (currently starting around line 366 with `keytool -genkeypair`) so it only regenerates when the files are missing:

```yaml
          else
            if [[ -f ci-validation.keystore && -f key.properties ]]; then
              echo "Reusing cached CI-validation keystore (stable across RC builds)"
            else
              keytool -genkeypair \
                -v \
                -keystore ci-validation.keystore \
                -storepass ci-validation-password \
                -keypass ci-validation-password \
                -alias ci-validation \
                -keyalg RSA \
                -keysize 2048 \
                -validity 10000 \
                -dname "CN=Airo TV CI Validation,O=DevelopersCoffee,C=US"
              {
                echo "storeFile=ci-validation.keystore"
                echo "storePassword=ci-validation-password"
                echo "keyAlias=ci-validation"
                echo "keyPassword=ci-validation-password"
              } > key.properties
            fi
          fi
```

Keep the surrounding `if [[ "$PRODUCTION_SIGNING" == "true" ]]` / `else` structure exactly as-is — only the body of the `else` branch changes.

- [ ] **Step 4: Verify YAML syntax**

Run: `cd .github/workflows && python3 -c "import yaml; yaml.safe_load(open('airo-tv-release.yml'))" && echo OK`
Expected: `OK` with no exception.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/airo-tv-release.yml
git commit -m "fix(ci): cache CI-validation Android keystore so RC-to-RC updates share a signing identity"
```

---

### Task 2: Verify with a real workflow dispatch

**Files:** none (verification task)

**Interfaces:**
- Consumes: Task 1's workflow change.
- Produces: confirmation evidence for the PR description in Task 3.

- [ ] **Step 1: Trigger two sequential dispatches on the branch**

This requires pushing the branch and running the workflow twice via `gh workflow run` (or via whatever workflow triggers `airo-tv-release.yml` as a reusable workflow — check `v2-release-orchestrator.yml` for the calling convention first: `grep -n "airo-tv-release" .github/workflows/v2-release-orchestrator.yml`).

Run the orchestrator with `production_signing=false` twice, a few minutes apart. Download both runs' `ci-validation.keystore` cache-restore logs (or the built APK) and compare signing certs:

```bash
keytool -printcert -jarfile <first-run-apk.apk> > /tmp/run1-cert.txt
keytool -printcert -jarfile <second-run-apk.apk> > /tmp/run2-cert.txt
diff /tmp/run1-cert.txt /tmp/run2-cert.txt
```

Expected: no diff — same certificate fingerprint (`SHA256` line) both runs.

- [ ] **Step 2: No commit** — this is a CI verification step, evidence goes into the PR description.

---

### Task 3: File follow-up issue for the mobile/tablet workflow, open PR

**Files:** none (process task)

**Interfaces:**
- Consumes: Task 1 + Task 2.
- Produces: nothing further downstream.

- [ ] **Step 1: File a follow-up issue**

`.github/workflows/airo-mobile-tablet-release.yml:363` has the identical `keytool -genkeypair`-every-run pattern. Same bug, separate workflow, out of scope for the TV-focused rc.4 sprint.

```bash
gh issue create --repo DevelopersCoffee/airo \
  --title "CI: airo-mobile-tablet-release.yml has the same ephemeral-signing-key bug as airo-tv-release.yml" \
  --body "Same root cause fixed for Airo TV in <PR from Task 1's step below>: keytool -genkeypair regenerates a random key every run when production_signing=false, breaking RC-to-RC mobile/tablet updates the same way. Apply the same actions/cache fix to airo-mobile-tablet-release.yml:340-380 (adjust line numbers to that file)." \
  --label bug
```

- [ ] **Step 2: Open PR**

```bash
git push -u origin worktree-rc-signing-key-stability
gh pr create --repo DevelopersCoffee/airo \
  --title "fix(ci): stabilize CI-validation Android signing key across RC builds" \
  --body "Fixes INSTALL_FAILED_UPDATE_INCOMPATIBLE on RC-to-RC device updates found during the 2026-07-20 Pixel 9 rc.3 dogfood pass. Root cause: keytool -genkeypair regenerated a random key every airo-tv-release.yml run when production_signing=false. Fix: cache the keystore with a stable actions/cache key so it's generated once and reused.

Verified: two sequential workflow dispatches produce identical signing cert fingerprints (see Task 2).

Follow-up filed for the identical bug in airo-mobile-tablet-release.yml: #<issue-number-from-step-1>

## Test plan
- [x] YAML syntax valid
- [x] Two sequential dispatches produce matching keytool -printcert output"
```

- [ ] **Step 3: Route through chief-release-devops-officer review, merge**

This is a CI/release workflow change — required reviewer per the Engineering Council roster.
