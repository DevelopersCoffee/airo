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
- [ ] Manual QA sign-off (if required)

---

## 🟡 Build Verification

### Android
- [ ] Debug APK builds successfully
- [ ] Release APK builds successfully
- [ ] AAB (App Bundle) generates correctly
- [ ] APK size within acceptable limits (<100MB)
- [ ] ProGuard/R8 rules applied correctly

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

