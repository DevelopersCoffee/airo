# 📦 Publishing APKs to GitHub for Public Download

## Overview
This guide explains how to publish APK files to GitHub Releases so anyone can download and install the Airo Super App on their Android devices.

---

## 🎯 Quick Start (TL;DR)

```bash
# 1. Commit your changes
git add .
git commit -m "Release v1.0.0"
git push

# 2. Create and push a tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"
git push origin v1.0.0

# 3. Wait ~15 minutes for GitHub Actions to build
# 4. APK will be available at: https://github.com/DevelopersCoffee/airo/releases/tag/v1.0.0
```

---

## 📋 Prerequisites

### 1. GitHub Secrets Setup
You need to configure one secret in your GitHub repository:

**Go to**: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

**Required Secret**:
- **Name**: `GOOGLE_SERVICES_JSON`
- **Value**: Base64-encoded content of `app/android/app/google-services.json`

**How to create the secret**:
```bash
# On Linux/Mac:
base64 -w 0 app/android/app/google-services.json

# On Windows (PowerShell):
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app\android\app\google-services.json"))
```

Copy the output and paste it as the secret value.

### 2. Verify Workflow Files
Ensure these files exist (they already do):
- ✅ `.github/workflows/build-and-release.yml` - Builds and publishes releases
- ✅ `.github/workflows/ci.yml` - Runs tests on every push

---

## 🚀 Publishing a Release

### Step 1: Prepare Your Code
```bash
# Make sure all changes are committed
git status

# If you have uncommitted changes:
git add .
git commit -m "Prepare for release v1.0.0"
git push
```

### Step 2: Create a Git Tag
```bash
# Create an annotated tag (recommended)
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"

# Or create a lightweight tag
git tag v1.0.0

# Push the tag to GitHub
git push origin v1.0.0
```

**Tag Naming Convention**:
- `v1.0.0` - Major release (breaking changes)
- `v1.1.0` - Minor release (new features)
- `v1.0.1` - Patch release (bug fixes)
- `v1.0.0-beta.1` - Pre-release (beta testing)
- `v1.0.0-alpha.1` - Pre-release (alpha testing)

### Step 3: Monitor the Build
1. Go to: `https://github.com/DevelopersCoffee/airo/actions`
2. You'll see a workflow running: "Build and Release"
3. Click on it to see progress
4. Wait ~15-20 minutes for all platforms to build

**What's being built**:
- ✅ Android APK (release)
- ✅ Android AAB (Google Play)
- ✅ iOS IPA (unsigned)
- ✅ Web (ZIP)
- ✅ Windows (ZIP)
- ✅ Linux (TAR.GZ)

### Step 4: Verify the Release
1. Go to: `https://github.com/DevelopersCoffee/airo/releases`
2. You should see your new release (e.g., `v1.0.0`)
3. Click on it to see all downloadable files

**Files available for download**:
- `app-release.apk` - Android APK (~50 MB)
- `app-release.aab` - Android App Bundle for Play Store (~40 MB)
- `app-release.ipa` - iOS IPA (~100 MB)
- `airo-web-release.zip` - Web build (~30 MB)
- `airo-windows-release.zip` - Windows build (~80 MB)
- `airo-linux-release.tar.gz` - Linux build (~60 MB)
- `RELEASE_NOTES.md` - Auto-generated release notes

---

## 📱 How Users Download and Install

### For Android Users

**Step 1: Download APK**
1. Go to: `https://github.com/DevelopersCoffee/airo/releases/latest`
2. Click on `app-release.apk` to download

**Step 2: Enable Unknown Sources**
1. Open **Settings** on Android device
2. Go to **Security** or **Privacy**
3. Enable **Install unknown apps** for your browser (Chrome, Firefox, etc.)

**Step 3: Install APK**
1. Open the downloaded `app-release.apk` file
2. Tap **Install**
3. Wait for installation to complete
4. Tap **Open** to launch the app

**Alternative: Using ADB**
```bash
# Download APK from GitHub
wget https://github.com/DevelopersCoffee/airo/releases/download/v1.0.0/app-release.apk

# Install via ADB
adb install app-release.apk
```

---

## 🔧 Advanced: Customizing Releases

### Adding Release Notes
Create a file `RELEASE_NOTES.md` in your repository root before tagging:

```markdown
# Release v1.0.0 - Initial Public Release

## 🎉 New Features
- ✅ AI-powered chat assistant with Gemini Nano
- ✅ 6 sample prompts for quick actions
- ✅ Chess game with Stockfish AI
- ✅ Music player with playlist support
- ✅ Multi-platform support (Android, iOS, Web)

## 🐛 Bug Fixes
- Fixed AI streaming threading issue
- Improved audio playback stability

## 📱 Installation
Download `app-release.apk` and install on your Android device.

## 🔐 Security
- No hardcoded secrets
- SQLCipher encryption ready
- Secure local storage

## 📊 Performance
- Cold start: <3s
- Memory: ~250MB
- Battery: <5% per hour
```

### Building Locally Before Release
```bash
# Build release APK locally
cd app
flutter build apk --release

# Test the APK
adb install build/app/outputs/flutter-apk/app-release.apk

# If everything works, create the tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Creating Pre-releases
```bash
# Create a beta release
git tag -a v1.0.0-beta.1 -m "Beta release for testing"
git push origin v1.0.0-beta.1
```

In the GitHub Release, check the **"This is a pre-release"** checkbox.

---

## 📊 Release Checklist

Before creating a release, ensure:

- [ ] All tests pass (`make test`)
- [ ] Code is formatted (`make format`)
- [ ] No linting errors (`make lint`)
- [ ] Version updated in `app/pubspec.yaml`
- [ ] CHANGELOG.md updated
- [ ] RELEASE_NOTES.md created
- [ ] All changes committed and pushed
- [ ] GitHub secret `GOOGLE_SERVICES_JSON` is set
- [ ] Build tested locally

---

## 🌐 Making Releases Discoverable

### 1. Add Download Badge to README
```markdown
[![Download APK](https://img.shields.io/github/v/release/DevelopersCoffee/airo?label=Download%20APK)](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)
```

### 2. Create a Releases Page
Add to your `README.md`:
```markdown
## 📥 Download

### Android
[Download Latest APK](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)

### iOS
[Download Latest IPA](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.ipa)

### Web
[Download Web Build](https://github.com/DevelopersCoffee/airo/releases/latest/download/airo-web-release.zip)

### All Releases
[View All Releases](https://github.com/DevelopersCoffee/airo/releases)
```

### 3. Pin Latest Release
GitHub automatically shows the latest release on your repository homepage.

---

## 🔄 Automated Release Workflow

The workflow (`.github/workflows/build-and-release.yml`) automatically:

1. ✅ **Triggers** when you push a tag (e.g., `v1.0.0`)
2. ✅ **Builds** all platforms in parallel
3. ✅ **Signs** Android APK/AAB (if keystore configured)
4. ✅ **Creates** GitHub Release
5. ✅ **Uploads** all build artifacts
6. ✅ **Generates** release notes from commits
7. ✅ **Publishes** release (public download)

**Build Time**: ~15-20 minutes (parallel builds)

---

## 🔐 Signing APKs (Optional but Recommended)

For production releases, you should sign your APK with a keystore.

### Generate Keystore
```bash
keytool -genkey -v -keystore airo-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias airo-key
```

### Add to GitHub Secrets
1. **KEYSTORE_FILE**: Base64-encoded keystore file
2. **KEYSTORE_PASSWORD**: Keystore password
3. **KEY_ALIAS**: Key alias (e.g., `airo-key`)
4. **KEY_PASSWORD**: Key password

### Update Workflow
The workflow already supports signing if secrets are configured.

---

## 📈 Monitoring Downloads

### View Download Stats
1. Go to: `https://github.com/DevelopersCoffee/airo/releases`
2. Each release shows download count for each asset
3. Click on a release to see detailed stats

### Using GitHub API
```bash
# Get latest release info
curl https://api.github.com/repos/DevelopersCoffee/airo/releases/latest

# Get all releases
curl https://api.github.com/repos/DevelopersCoffee/airo/releases
```

---

## 🚨 Troubleshooting

### Build Fails
**Check**:
1. GitHub Actions logs: `Actions` tab → Click on failed workflow
2. Ensure `GOOGLE_SERVICES_JSON` secret is set correctly
3. Verify `pubspec.yaml` dependencies are valid
4. Check Flutter version in workflow matches your local version

### APK Won't Install
**Solutions**:
1. Enable "Install unknown apps" in Android settings
2. Download APK again (may be corrupted)
3. Check Android version compatibility (min SDK 24)
4. Try installing via ADB

### Release Not Created
**Check**:
1. Tag was pushed to GitHub: `git push origin v1.0.0`
2. Workflow completed successfully
3. No errors in GitHub Actions logs

---

## 📚 Additional Resources

- **GitHub Releases Docs**: https://docs.github.com/en/repositories/releasing-projects-on-github
- **Flutter Build Docs**: https://docs.flutter.dev/deployment/android
- **Semantic Versioning**: https://semver.org/

---

## 🎉 Example: First Release

```bash
# 1. Update version in pubspec.yaml
# version: 1.0.0+1

# 2. Create release notes
cat > RELEASE_NOTES.md << 'EOF'
# Airo Super App v1.0.0 - Initial Release

First public release of Airo Super App!

## Features
- AI Chat Assistant
- Chess Game
- Music Player
- Multi-platform support

Download the APK and enjoy!
EOF

# 3. Commit and push
git add .
git commit -m "Release v1.0.0"
git push

# 4. Create and push tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial public release"
git push origin v1.0.0

# 5. Wait for build (~15 min)
# 6. Share the link: https://github.com/DevelopersCoffee/airo/releases/tag/v1.0.0
```

---

## ✅ Summary

**To publish an APK for public download**:
1. Set up `GOOGLE_SERVICES_JSON` secret (one-time)
2. Create and push a git tag (e.g., `v1.0.0`)
3. Wait for GitHub Actions to build (~15 min)
4. Share the release URL with users

**Users can download from**:
- Latest release: `https://github.com/DevelopersCoffee/airo/releases/latest`
- Direct APK link: `https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk`

That's it! 🎉

