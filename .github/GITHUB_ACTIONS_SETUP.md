# GitHub Actions Setup Guide

## 🔐 Required Secrets

Add these secrets to your GitHub repository for CI/CD to work properly.

### Step 1: Go to Repository Settings
1. Navigate to your repository on GitHub
2. Click **Settings** (top right)
3. Click **Secrets and variables** → **Actions**

### Step 2: Add Required Secrets

#### 1. GOOGLE_SERVICES_JSON
Firebase configuration for Android builds

**How to get:**
1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Download `google-services.json`
4. Encode it to base64:
   ```bash
   cat app/android/app/google-services.json | base64 -w 0
   ```
5. Copy the output

**Add to GitHub:**
1. Click **New repository secret**
2. Name: `GOOGLE_SERVICES_JSON`
3. Value: Paste the base64 encoded content
4. Click **Add secret**

#### 2. GITHUB_TOKEN
Automatically provided by GitHub Actions (no action needed)

### Step 3: Verify Secrets

```bash
# List secrets (local only)
gh secret list
```

## 🚀 Triggering Workflows

### Automatic Triggers

**CI Workflow** - Runs on every push
```bash
git push origin main
```

**PR Checks** - Runs on pull requests
```bash
# Create and push a pull request
git push origin feature-branch
```

**Release Workflow** - Runs on tag push
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Manual Triggers

1. Go to **Actions** tab
2. Select workflow
3. Click **Run workflow**
4. Fill in inputs if needed
5. Click **Run workflow**

## 📊 Workflow Status

### View Workflow Runs
1. Go to **Actions** tab
2. Click on workflow name
3. View all runs

### View Logs
1. Click on specific run
2. Click on job
3. Expand steps to see logs

### Download Artifacts
1. Click on workflow run
2. Scroll to **Artifacts**
3. Download desired file

## 🔍 Troubleshooting

### Build Fails with "Secret not found"
- Verify secret is added correctly
- Check secret name matches workflow
- Ensure secret is not empty

### Firebase Config Error
- Verify `google-services.json` is valid JSON
- Check base64 encoding is correct
- Ensure Firebase project is active

### Build Timeout
- Check runner logs for errors
- Verify dependencies are available
- Check network connectivity

### Release Not Created
- Verify tag format: `v1.0.0`
- Check workflow permissions
- Verify GITHUB_TOKEN is available

## 📋 Workflow Files

| File | Purpose | Trigger |
|------|---------|---------|
| `build-and-release.yml` | Build all platforms | Tag push (v*) |
| `ci.yml` | Continuous integration | Push to main/develop |
| `pr-checks.yml` | Pull request validation | Pull request |
| `version-and-changelog.yml` | Version management | Manual |

## 🎯 Release Process

### Step 1: Prepare Release
```bash
# Update version in pubspec.yaml
# Update CHANGELOG.md
# Commit changes
git add .
git commit -m "chore: prepare v1.0.0 release"
git push origin main
```

### Step 2: Create Tag
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Step 3: Wait for Build
- GitHub Actions automatically triggers
- Builds all platforms
- Creates release with executables

### Step 4: Download
- Go to Releases page
- Download desired executable

## 📦 Release Assets

Each release includes:

| Asset | Platform | Format |
|-------|----------|--------|
| `app-release.apk` | Android | APK |
| `app-release.aab` | Android | AAB |
| `app-release.ipa` | iOS | IPA |
| `airo-web-release.zip` | Web | ZIP |
| `airo-windows-release.zip` | Windows | ZIP |
| `airo-linux-release.tar.gz` | Linux | TAR.GZ |

## 🛠️ Local Testing

### Test Build Locally
```bash
# Android
make build-android

# iOS (macOS only)
make build-ios

# Web
make build-web

# Windows
make build-windows

# Linux
make build-linux

# All platforms
make build-release-all
```

## 📞 Support

### Common Issues

**Q: Build fails with "Flutter not found"**
A: Ensure Flutter is installed and in PATH

**Q: APK build fails**
A: Check Java version (17+) and Android SDK

**Q: iOS build fails**
A: Ensure Xcode is installed (macOS only)

**Q: Web build fails**
A: Check Node.js version (14+)

### Getting Help

1. Check workflow logs
2. Review this documentation
3. Check GitHub Actions docs
4. Create GitHub issue

## ✅ Checklist

- [ ] Added GOOGLE_SERVICES_JSON secret
- [ ] Verified secrets in Settings
- [ ] Tested CI workflow
- [ ] Tested PR checks
- [ ] Created test release
- [ ] Downloaded release assets
- [ ] Verified all platforms build

## 🚀 Next Steps

1. Add secrets to GitHub
2. Test CI/CD pipeline
3. Create first release
4. Monitor builds
5. Iterate and improve

---

**Last Updated**: November 2, 2025
**Status**: ✅ Ready for use

