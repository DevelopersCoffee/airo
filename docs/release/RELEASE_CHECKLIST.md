# 📋 Release Checklist

Pre-release verification checklist for Airo Super App releases.

---

## 🔴 Pre-Release Checks

### Code Quality
- [ ] All CI checks passing (analyze, test, lint)
- [ ] No critical/high severity security vulnerabilities
- [ ] Code review completed for all merged PRs
- [ ] No TODO comments with release blockers

### Version Control
- [ ] Version bumped in `app/pubspec.yaml`
- [ ] CHANGELOG.md updated (git-cliff generated)
- [ ] Release branch created (if applicable)
- [ ] All feature branches merged

### Testing
- [ ] Unit tests passing (>80% coverage target)
- [ ] Integration tests passing
- [ ] E2E smoke tests passing
- [ ] Shared UI responsiveness suite passing (`make test-ui-responsive`)
- [ ] Database reliability validation suite passing (`make test-database-reliability`)
- [ ] Background processing validation suite passing (`make test-background-processing`)
- [ ] Meeting search validation suite passing (`make test-meeting-search`)
- [ ] Performance benchmark report created (`artifacts/performance/...`)
- [ ] Battery impact measurements attached or explicitly waived
- [ ] Manual QA sign-off (if required)

---

## 🟡 Build Verification

### Android
- [ ] Debug APK builds successfully
- [ ] Release APK builds successfully
- [ ] AAB (App Bundle) generates correctly
- [ ] APK size within acceptable limits (<100MB)
- [ ] ProGuard/R8 rules applied correctly
- [ ] Cold and warm startup timings recorded
- [ ] Android memory/storage snapshots attached

### iOS
- [ ] Release build compiles
- [ ] No signing errors (or --no-codesign for CI)
- [ ] IPA generates correctly

### Web
- [ ] Web build generates
- [ ] Assets load correctly
- [ ] No console errors on startup

---

## 🟢 Smoke Test Checklist

### Critical Path Tests
| Feature | Test | Expected |
|---------|------|----------|
| App Launch | Cold start | App opens <3s |
| Navigation | Tab switching | All tabs accessible |
| Coins | View balance | Data loads |
| Quest | Ask question | AI responds |
| Beats | Browse music | List displays |
| Arena | Open games | Games load |
| Loot | View deals | Feed renders |
| Tales | Open reader | Content shows |

### Network Tests
- [ ] Offline mode: App doesn't crash
- [ ] Slow network: Loading states show
- [ ] Network recovery: Data refreshes

### Platform-Specific
- [ ] Android: Back button works correctly
- [ ] iOS: Gestures work (swipe back)
- [ ] Web: Browser navigation works

### Google Cast V1

- [ ] Android sender discovers and casts to Chromecast-enabled TV.
- [ ] iOS sender shows local network permission and discovers the same receiver class.
- [ ] Public HLS IPTV channel plays on receiver without TV app installation.
- [ ] Unsupported header/auth streams fail without proxying.
- [ ] No full IPTV URLs are present in debug logs, analytics logs, or bug-report logs.
- [ ] AirPlay, browser receiver, local file casting, and multi-device UI are not visible in V1.

---

## 🔵 Rollback Criteria

**Immediate Rollback Required If:**
- [ ] Crash rate >5% on any platform
- [ ] Critical feature completely broken
- [ ] Data loss reported
- [ ] Security vulnerability discovered
- [ ] Payment processing failures

**Monitor Closely (Potential Rollback):**
- [ ] Crash rate 2-5%
- [ ] Significant performance regression
- [ ] High volume of user complaints
- [ ] Analytics show major drop-off

---

## 📦 Release Artifacts

### Required Artifacts
- [ ] `app-release.apk` - Android direct install
- [ ] `app-release.aab` - Play Store upload
- [ ] `app-release.ipa` - iOS (if applicable)
- [ ] `airo-web-release.zip` - Web deployment
- [ ] `RELEASE_NOTES.md` - Release description

### Documentation
- [ ] Changelog entry added
- [ ] Release notes written
- [ ] Known issues documented
- [ ] Migration guide (if breaking changes)
- [ ] [Database reliability validation runbook](./DATABASE_RELIABILITY_VALIDATION.md) followed
- [ ] [Meeting search validation runbook](./MEETING_SEARCH_VALIDATION.md) followed
- [ ] [Background processing validation runbook](./BACKGROUND_PROCESSING_VALIDATION.md) followed
- [ ] [UI responsiveness validation runbook](./UI_RESPONSIVENESS_VALIDATION.md) followed
- [ ] [Performance benchmark runbook](./PERFORMANCE_BENCHMARKS.md) followed

---

## ✅ Final Sign-Off

```
Release Version: v__.__.__
Release Date: ____-__-__
Release Manager: _______________

Code Quality:      [ ] Approved
Build Status:      [ ] Verified
Smoke Tests:       [ ] Passed
Documentation:     [ ] Complete

APPROVED FOR RELEASE: [ ] YES  [ ] NO

Signature: _______________________
Date: ____-__-__
```

---

## 🔗 Quick Links

- [Smoke Tests Workflow](/.github/workflows/smoke-tests.yml)
- [Build & Release Workflow](/.github/workflows/build-and-release.yml)
- [Rollback Procedure](./ROLLBACK_PROCEDURE.md)
- [Store Compliance](./STORE_COMPLIANCE.md)
- [Database Reliability Validation](./DATABASE_RELIABILITY_VALIDATION.md)
- [Meeting Search Validation](./MEETING_SEARCH_VALIDATION.md)
- [Background Processing Validation](./BACKGROUND_PROCESSING_VALIDATION.md)
- [UI Responsiveness Validation](./UI_RESPONSIVENESS_VALIDATION.md)
- [Performance Benchmarks](./PERFORMANCE_BENCHMARKS.md)
