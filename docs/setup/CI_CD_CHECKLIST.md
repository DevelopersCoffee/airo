# ✅ CI/CD Setup Checklist - Airo Super App

## 🎯 Pre-Release Setup

### GitHub Configuration
- [ ] Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions
- [ ] Click **New repository secret**
- [ ] Add `GOOGLE_SERVICES_JSON` secret
  - [ ] Encode `app/android/app/google-services.json` to base64
  - [ ] Paste base64 content as secret value
- [ ] Verify secret is saved

### Verify Workflows
- [ ] Go to: https://github.com/DevelopersCoffee/airo/actions
- [ ] Verify all 4 workflows are present:
  - [ ] build-and-release.yml
  - [ ] ci.yml
  - [ ] pr-checks.yml
  - [ ] version-and-changelog.yml

### Test CI Pipeline
- [ ] Push a commit to main branch
- [ ] Go to Actions tab
- [ ] Verify CI workflow runs
- [ ] Check build status

## 🚀 Creating Your First Release

### Step 1: Prepare
- [ ] Update `app/pubspec.yaml` version
- [ ] Update `CHANGELOG.md` with changes
- [ ] Review all changes
- [ ] Commit: `git commit -m "chore: prepare v1.0.0 release"`
- [ ] Push: `git push origin main`

### Step 2: Create Tag
- [ ] Create tag: `git tag -a v1.0.0 -m "Release v1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Verify tag on GitHub

### Step 3: Monitor Build
- [ ] Go to: https://github.com/DevelopersCoffee/airo/actions
- [ ] Click on **build-and-release** workflow
- [ ] Monitor build progress
- [ ] Wait for all platforms to complete (~90 minutes)

### Step 4: Verify Release
- [ ] Go to: https://github.com/DevelopersCoffee/airo/releases
- [ ] Verify release is created
- [ ] Check all 6 assets are present:
  - [ ] app-release.apk (Android)
  - [ ] app-release.aab (Android)
  - [ ] app-release.ipa (iOS)
  - [ ] airo-web-release.zip (Web)
  - [ ] airo-windows-release.zip (Windows)
  - [ ] airo-linux-release.tar.gz (Linux)
- [ ] Verify release notes are present
- [ ] Test download links

## 📋 Continuous Integration

### On Every Push
- [ ] CI workflow runs automatically
- [ ] Code analysis passes
- [ ] Tests pass
- [ ] Build succeeds
- [ ] No security issues

### On Pull Requests
- [ ] PR checks run automatically
- [ ] Secrets are not exposed
- [ ] Build verification passes
- [ ] PR comment with status appears

## 🛠️ Local Development

### Build Commands
- [ ] Test `make build-android`
- [ ] Test `make build-web`
- [ ] Test `make build-release-all`
- [ ] Verify builds complete successfully

### Documentation
- [ ] Read `RELEASE_GUIDE.md`
- [ ] Read `CI_CD_SETUP.md`
- [ ] Read `.github/GITHUB_ACTIONS_SETUP.md`
- [ ] Understand release process

## 📦 Release Assets

### Android
- [ ] APK file present (50 MB)
- [ ] AAB file present (40 MB)
- [ ] Both files downloadable
- [ ] File sizes reasonable

### iOS
- [ ] IPA file present (100 MB)
- [ ] File downloadable
- [ ] File size reasonable

### Web
- [ ] ZIP file present (30 MB)
- [ ] File downloadable
- [ ] Can extract and open in browser

### Windows
- [ ] ZIP file present (80 MB)
- [ ] File downloadable
- [ ] Can extract and run

### Linux
- [ ] TAR.GZ file present (60 MB)
- [ ] File downloadable
- [ ] Can extract and run

## 🔐 Security

### Secrets Management
- [ ] GOOGLE_SERVICES_JSON secret added
- [ ] No other secrets needed
- [ ] GITHUB_TOKEN automatically provided
- [ ] No sensitive data in workflows

### Code Security
- [ ] No hardcoded API keys
- [ ] No hardcoded passwords
- [ ] No sensitive data in code
- [ ] Security scan passes

## 📊 Monitoring

### Build Status
- [ ] Check Actions tab regularly
- [ ] Monitor build times
- [ ] Check for failures
- [ ] Review logs if needed

### Release Status
- [ ] Verify releases are created
- [ ] Check asset downloads
- [ ] Monitor user feedback
- [ ] Track issues

## 🎯 Ongoing Maintenance

### Regular Tasks
- [ ] Update dependencies monthly
- [ ] Review security alerts
- [ ] Update documentation
- [ ] Monitor build times

### Version Management
- [ ] Use semantic versioning
- [ ] Update CHANGELOG.md
- [ ] Create meaningful release notes
- [ ] Tag releases properly

### Team Communication
- [ ] Share release process with team
- [ ] Document any changes
- [ ] Update team on new features
- [ ] Gather feedback

## ✅ Final Verification

### Everything Working?
- [ ] CI pipeline runs on push
- [ ] PR checks run on pull requests
- [ ] Release builds all platforms
- [ ] GitHub release created
- [ ] All assets present
- [ ] Users can download

### Documentation Complete?
- [ ] RELEASE_GUIDE.md reviewed
- [ ] CI_CD_SETUP.md reviewed
- [ ] GITHUB_ACTIONS_SETUP.md reviewed
- [ ] Team trained on process

### Ready for Production?
- [ ] All tests passing
- [ ] Security scan clean
- [ ] Code reviewed
- [ ] Release notes complete
- [ ] Assets verified

## 🚀 You're Ready!

Once all items are checked:
1. ✅ CI/CD pipeline is fully operational
2. ✅ Releases are automated
3. ✅ Users can download executables
4. ✅ Team can collaborate effectively
5. ✅ Quality is maintained

---

## 📞 Quick Reference

### Important URLs
- **Repository**: https://github.com/DevelopersCoffee/airo
- **Releases**: https://github.com/DevelopersCoffee/airo/releases
- **Actions**: https://github.com/DevelopersCoffee/airo/actions
- **Secrets**: https://github.com/DevelopersCoffee/airo/settings/secrets/actions

### Key Commands
```bash
# Create release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Build locally
make build-release-all

# View logs
git log --oneline -5
```

### Documentation Files
- `RELEASE_GUIDE.md` - How to release
- `CI_CD_SETUP.md` - Setup guide
- `CI_CD_SUMMARY.md` - Overview
- `.github/GITHUB_ACTIONS_SETUP.md` - GitHub setup

---

**Status**: ✅ **READY FOR RELEASES**
**Date**: November 2, 2025
**Next Step**: Add GitHub secret and create first release!

