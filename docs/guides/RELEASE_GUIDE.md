# Release Guide - Airo Super App

## 📋 Overview

This guide explains how to create releases for the Airo super app. Releases are automatically built for all platforms and published to GitHub.

## 🚀 Release Process

### Step 1: Prepare for Release

1. **Update Version**
   ```bash
   # Edit app/pubspec.yaml
   version: 1.0.0+1
   ```

2. **Update Changelog**
   ```bash
   # Edit CHANGELOG.md
   ## [1.0.0] - 2025-11-02
   
   ### Added
   - Feature 1
   - Feature 2
   
   ### Fixed
   - Bug fix 1
   - Bug fix 2
   ```

3. **Commit Changes**
   ```bash
   git add app/pubspec.yaml CHANGELOG.md
   git commit -m "chore: prepare v1.0.0 release"
   git push origin main
   ```

### Step 2: Create Release Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0"

# Push tag to GitHub
git push origin v1.0.0
```

### Step 3: Wait for Build

- GitHub Actions automatically triggers
- Builds all platforms (Android, iOS, Web, Windows, Linux)
- Creates GitHub release with all executables
- Takes approximately 60-90 minutes

### Step 4: Verify Release

1. Go to GitHub Releases page
2. Verify all assets are present
3. Check release notes
4. Test download links

### Step 5: Publish Release

1. Go to GitHub Releases page
2. Click on release
3. Click **Edit**
4. Uncheck **This is a pre-release** if ready
5. Click **Update release**

## 📦 Release Assets

### Android
- **app-release.apk** - Direct installation
  - Size: ~50 MB
  - Installation: `adb install app-release.apk`
  
- **app-release.aab** - Google Play Store
  - Size: ~40 MB
  - Upload to Google Play Console

### iOS
- **app-release.ipa** - iOS app
  - Size: ~100 MB
  - Installation: Xcode or Apple Configurator 2
  - TestFlight: Upload for beta testing

### Web
- **airo-web-release.zip** - Web app
  - Size: ~30 MB
  - Extract and open index.html in browser
  - Deploy to web server

### Windows
- **airo-windows-release.zip** - Windows executable
  - Size: ~80 MB
  - Extract and run airo.exe
  - No installation required

### Linux
- **airo-linux-release.tar.gz** - Linux binary
  - Size: ~60 MB
  - Extract and run ./airo
  - Make executable: `chmod +x airo`

## 🔄 Version Numbering

Use Semantic Versioning: `MAJOR.MINOR.PATCH`

### Major (v2.0.0)
- Breaking changes
- Significant new features
- Major refactoring

### Minor (v1.1.0)
- New features
- Backward compatible
- No breaking changes

### Patch (v1.0.1)
- Bug fixes
- Minor improvements
- No new features

## 📝 Release Notes Template

```markdown
# Release v1.0.0

## 🎉 Highlights
- Feature 1
- Feature 2
- Feature 3

## ✨ New Features
- Feature A
- Feature B

## 🐛 Bug Fixes
- Fixed issue 1
- Fixed issue 2

## 📦 Downloads
- Android: app-release.apk
- iOS: app-release.ipa
- Web: airo-web-release.zip
- Windows: airo-windows-release.zip
- Linux: airo-linux-release.tar.gz

## 🔐 Security
- Security fix 1
- Security fix 2

## 📋 Known Issues
- Issue 1
- Issue 2

## 🙏 Thanks
Thanks to all contributors!
```

## 🛠️ Local Release Build

### Build All Platforms Locally

```bash
# Build all platforms
make build-release-all

# Or build individually
make build-android
make build-android-bundle
make build-ios
make build-web
make build-windows
make build-linux
```

### Create Local Release Archive

```bash
# Create directory
mkdir -p releases/v1.0.0

# Copy all builds
cp app/build/app/outputs/flutter-apk/app-release.apk releases/v1.0.0/
cp app/build/app/outputs/bundle/release/app-release.aab releases/v1.0.0/
cp app/app-release.ipa releases/v1.0.0/
cp airo-web-release.zip releases/v1.0.0/
cp airo-windows-release.zip releases/v1.0.0/
cp airo-linux-release.tar.gz releases/v1.0.0/

# Create archive
tar -czf airo-v1.0.0-all-platforms.tar.gz releases/v1.0.0/
```

## 🔍 Verification Checklist

- [ ] Version updated in pubspec.yaml
- [ ] Changelog updated
- [ ] All tests passing
- [ ] Code reviewed
- [ ] Tag created with correct format
- [ ] Tag pushed to GitHub
- [ ] All builds completed successfully
- [ ] All assets present in release
- [ ] Release notes complete
- [ ] Download links working

## 🚨 Troubleshooting

### Build Failed
1. Check workflow logs
2. Verify secrets are set
3. Check for compilation errors
4. Review platform-specific issues

### Missing Assets
1. Check individual build logs
2. Verify platform dependencies
3. Check artifact upload steps
4. Verify storage limits

### Release Not Created
1. Verify tag format (v1.0.0)
2. Check workflow permissions
3. Verify GITHUB_TOKEN available
4. Check for build errors

## 📊 Release Timeline

| Step | Time | Notes |
|------|------|-------|
| Prepare | 15 min | Update version, changelog |
| Create Tag | 1 min | Push tag to GitHub |
| Android Build | 15 min | APK + AAB |
| iOS Build | 20 min | IPA (macOS runner) |
| Web Build | 10 min | ZIP archive |
| Windows Build | 15 min | ZIP archive |
| Linux Build | 15 min | TAR.GZ archive |
| Create Release | 5 min | GitHub release creation |
| **Total** | **~90 min** | All platforms |

## 🎯 Best Practices

1. **Test Before Release**
   ```bash
   flutter test
   make build-android
   ```

2. **Use Semantic Versioning**
   - Major: Breaking changes
   - Minor: New features
   - Patch: Bug fixes

3. **Write Clear Release Notes**
   - Highlight new features
   - List bug fixes
   - Note breaking changes

4. **Tag Releases Properly**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   ```

5. **Verify All Assets**
   - Check all platforms built
   - Verify file sizes
   - Test downloads

## 📞 Support

For issues:
1. Check workflow logs
2. Review this guide
3. Check GitHub Actions docs
4. Create GitHub issue

---

**Last Updated**: November 2, 2025
**Status**: ✅ Ready for releases

