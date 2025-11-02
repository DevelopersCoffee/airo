# CI/CD Setup - Airo Super App

## 📋 Overview

This document describes the CI/CD pipeline for the Airo super app. The pipeline automatically builds, tests, and releases the app across all platforms.

## 🔧 GitHub Actions Workflows

### 1. **build-and-release.yml** - Release Pipeline
Triggered when a tag is pushed (e.g., `v1.0.0`)

**Builds:**
- ✅ Android APK
- ✅ Android AAB (Google Play)
- ✅ iOS IPA
- ✅ Web (ZIP)
- ✅ Windows (ZIP)
- ✅ Linux (TAR.GZ)

**Output:** GitHub Release with all executables

### 2. **ci.yml** - Continuous Integration
Triggered on push to main/master/develop

**Checks:**
- ✅ Flutter analyze
- ✅ Code formatting
- ✅ Unit tests
- ✅ Debug APK build
- ✅ Security scan (Trivy)
- ✅ Linting

### 3. **pr-checks.yml** - Pull Request Validation
Triggered on pull requests

**Checks:**
- ✅ PR title validation
- ✅ Secret detection
- ✅ File change detection
- ✅ Build verification
- ✅ PR comments with status

### 4. **version-and-changelog.yml** - Version Management
Manual trigger for version bumping

**Actions:**
- ✅ Bump version (major/minor/patch)
- ✅ Update pubspec.yaml
- ✅ Generate changelog
- ✅ Create git tag
- ✅ Push to repository

## 🚀 How to Use

### Creating a Release

1. **Bump Version** (Optional)
   ```bash
   # Go to Actions → Version and Changelog
   # Click "Run workflow"
   # Select version type (major/minor/patch)
   # Wait for completion
   ```

2. **Create Tag**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

3. **Wait for Build**
   - GitHub Actions automatically triggers
   - Builds all platforms
   - Creates release with all executables

4. **Download from Release Page**
   - Go to https://github.com/DevelopersCoffee/airo/releases
   - Download desired executable

### Manual Workflow Trigger

1. Go to GitHub repository
2. Click "Actions" tab
3. Select workflow
4. Click "Run workflow"
5. Fill in inputs if needed
6. Click "Run workflow"

## 🔐 Required Secrets

Add these to GitHub repository settings (Settings → Secrets and variables → Actions):

### 1. GOOGLE_SERVICES_JSON
Firebase configuration (base64 encoded)

```bash
# Encode your google-services.json
cat app/android/app/google-services.json | base64 -w 0
# Copy output to GitHub secret
```

### 2. GITHUB_TOKEN
Automatically provided by GitHub Actions

## 📦 Release Assets

Each release includes:

| File | Platform | Format |
|------|----------|--------|
| `app-release.apk` | Android | APK |
| `app-release.aab` | Android | AAB (Play Store) |
| `app-release.ipa` | iOS | IPA |
| `airo-web-release.zip` | Web | ZIP |
| `airo-windows-release.zip` | Windows | ZIP |
| `airo-linux-release.tar.gz` | Linux | TAR.GZ |
| `RELEASE_NOTES.md` | All | Markdown |

## 📥 Installation Instructions

### Android
```bash
# APK (Direct installation)
adb install app-release.apk

# AAB (Google Play Store)
# Upload to Google Play Console
```

### iOS
```bash
# Using Xcode
open app-release.ipa

# Using Apple Configurator 2
# Or use TestFlight for beta testing
```

### Web
```bash
# Extract and open in browser
unzip airo-web-release.zip
open index.html
```

### Windows
```bash
# Extract and run
Expand-Archive airo-windows-release.zip
cd airo-windows-release
./airo.exe
```

### Linux
```bash
# Extract and run
tar -xzf airo-linux-release.tar.gz
chmod +x airo
./airo
```

## 🔍 Monitoring Builds

### View Build Status
1. Go to GitHub repository
2. Click "Actions" tab
3. View workflow runs
4. Click on specific run for details

### View Logs
1. Click on workflow run
2. Click on job
3. Expand steps to see logs

### Download Artifacts
1. Click on workflow run
2. Scroll to "Artifacts" section
3. Download desired artifact

## 🛠️ Troubleshooting

### Build Fails
1. Check workflow logs
2. Verify secrets are set correctly
3. Check Flutter version compatibility
4. Verify dependencies are available

### Release Not Created
1. Verify tag format (v1.0.0)
2. Check workflow permissions
3. Verify GITHUB_TOKEN is available
4. Check for build errors

### Missing Executables
1. Check individual build job logs
2. Verify platform-specific dependencies
3. Check artifact upload steps
4. Verify storage limits not exceeded

## 📊 Build Matrix

| Platform | Runner | Time | Size |
|----------|--------|------|------|
| Android | ubuntu-latest | ~15 min | ~50 MB |
| iOS | macos-latest | ~20 min | ~100 MB |
| Web | ubuntu-latest | ~10 min | ~30 MB |
| Windows | windows-latest | ~15 min | ~80 MB |
| Linux | ubuntu-latest | ~15 min | ~60 MB |

## 🔄 Workflow Triggers

| Workflow | Trigger | Branch |
|----------|---------|--------|
| build-and-release | Tag push (v*) | Any |
| ci | Push | main, master, develop |
| pr-checks | Pull request | main, master, develop |
| version-and-changelog | Manual | main |

## 📝 Best Practices

1. **Always test locally before pushing**
   ```bash
   flutter test
   flutter build apk --debug
   ```

2. **Use semantic versioning**
   - Major: Breaking changes
   - Minor: New features
   - Patch: Bug fixes

3. **Write meaningful commit messages**
   ```
   feat: add new feature
   fix: resolve bug
   docs: update documentation
   ```

4. **Review PR before merging**
   - Check CI status
   - Review code changes
   - Verify tests pass

5. **Tag releases properly**
   ```bash
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

## 🚀 Next Steps

1. Add secrets to GitHub
2. Test CI/CD pipeline
3. Create first release
4. Monitor builds
5. Iterate and improve

## 📞 Support

For issues:
1. Check workflow logs
2. Review this documentation
3. Check GitHub Actions documentation
4. Create GitHub issue

---

**Last Updated**: November 2, 2025
**Status**: ✅ Ready for use

