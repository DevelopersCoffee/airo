# 🔄 Rollback Procedure

Emergency rollback procedures for Airo Super App releases.

---

## ⚡ Quick Rollback Commands

### GitHub Release Rollback
```bash
# 1. Get previous stable version tag
git tag -l "v*" --sort=-v:refname | head -5

# 2. Create rollback release (points to previous version)
gh release create v<VERSION>-rollback \
  --title "Rollback to v<PREVIOUS_VERSION>" \
  --notes "Emergency rollback from v<BROKEN_VERSION>"
```

### APK Rollback (Direct)
```bash
# Download previous APK from releases
curl -L -o app-previous.apk \
  "https://github.com/DevelopersCoffee/airo/releases/download/v<VERSION>/app-release.apk"
```

---

## 📋 Rollback Decision Matrix

| Severity | Symptoms | Action | Timeline |
|----------|----------|--------|----------|
| 🔴 Critical | Crash on launch, data loss | Immediate rollback | <1 hour |
| 🟠 High | Major feature broken | Planned rollback | <4 hours |
| 🟡 Medium | Minor bugs, degraded UX | Hotfix preferred | <24 hours |
| 🟢 Low | Cosmetic issues | Next release | Normal cycle |

---

## 🚨 Immediate Rollback Steps

### Step 1: Assess Impact
```bash
# Check crash reports (if integrated)
# Monitor user feedback
# Check analytics for drop-off
```

### Step 2: Notify Team
- Post in team channel
- Tag release manager
- Document issue symptoms

### Step 3: Execute Rollback

#### Option A: GitHub Release (Recommended)
```bash
# Mark current release as pre-release (hides from latest)
gh release edit v<BROKEN_VERSION> --prerelease

# Verify previous release is now "latest"
gh release list
```

#### Option B: Revert Commit
```bash
# Create revert commit
git revert HEAD
git push origin main

# Re-tag with rollback marker
git tag -a v<VERSION>-reverted -m "Reverted due to <ISSUE>"
git push origin v<VERSION>-reverted
```

#### Option C: Re-release Previous Version
```bash
# Checkout previous stable tag
git checkout v<PREVIOUS_VERSION>

# Create new release tag
git tag -a v<NEW_VERSION>-stable -m "Stable re-release"
git push origin v<NEW_VERSION>-stable
```

---

## 📱 Platform-Specific Rollback

### Play Store (Android)
1. Go to Google Play Console
2. Navigate to Release > Production
3. Click "Manage" on problematic release
4. Select "Halt rollout" or set to 0%
5. Create new release with previous AAB
6. Resume staged rollout

### App Store (iOS)
1. Go to App Store Connect
2. Remove from sale (if critical)
3. Submit expedited review for fix
4. Or revert to previous build

### Web
```bash
# Deploy previous web build
cd app
git checkout v<PREVIOUS_VERSION>
flutter build web --release
# Deploy to hosting (Firebase/Vercel/etc.)
```

---

## 📊 Version Retention Policy

| Type | Retention | Location |
|------|-----------|----------|
| Release APKs | 90 days | GitHub Releases |
| Debug APKs | 5 days | GitHub Actions Artifacts |
| Source Tags | Permanent | Git repository |
| Changelogs | Permanent | Repository + GitHub Pages |

---

## ✅ Post-Rollback Checklist

- [ ] Verify rollback is live
- [ ] Confirm crash rate decreasing
- [ ] Update status page/changelog
- [ ] Create post-mortem issue
- [ ] Schedule fix review
- [ ] Communicate to users (if needed)

---

## 📝 Rollback Log Template

```markdown
## Rollback Record

**Date**: YYYY-MM-DD HH:MM UTC
**From Version**: v__.__.__
**To Version**: v__.__.__
**Reason**: 
**Impact**: 
**Duration**: 
**Root Cause**: 
**Prevention**: 
**Performed By**: 
```

---

## 🔗 Related

- [Release Checklist](./RELEASE_CHECKLIST.md)
- [Store Compliance](./STORE_COMPLIANCE.md)
- [CI/CD Pipeline](/docs/ci-cd/README.md)

