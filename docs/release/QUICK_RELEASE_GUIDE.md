# 🚀 Quick Release Guide - Airo Super App

## One-Command Release

```bash
# Create and publish a new release
./scripts/release.sh 1.0.0
```

---

## Manual Release (3 Steps)

### 1️⃣ Commit Changes
```bash
git add .
git commit -m "Release v1.0.0"
git push
```

### 2️⃣ Create Tag
```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### 3️⃣ Wait for Build
- Go to: https://github.com/DevelopersCoffee/airo/actions
- Wait ~15 minutes
- APK available at: https://github.com/DevelopersCoffee/airo/releases

---

## Release Types

| Type | Command | Example | When to Use |
|------|---------|---------|-------------|
| **Patch** | `make release-patch` | v1.0.1 | Bug fixes |
| **Minor** | `make release-minor` | v1.1.0 | New features |
| **Major** | `make release-major` | v2.0.0 | Breaking changes |
| **Beta** | Manual tag | v1.0.0-beta.1 | Testing |

---

## Pre-Release Checklist

```bash
# Run all checks
make test          # Run tests
make lint          # Check code quality
make format        # Format code
make analyze       # Analyze code

# Build locally to verify
cd app
flutter build apk --release
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Download Links for Users

### Latest Release
```
https://github.com/DevelopersCoffee/airo/releases/latest
```

### Direct APK Download
```
https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk
```

### All Releases
```
https://github.com/DevelopersCoffee/airo/releases
```

---

## Version Numbering

**Format**: `MAJOR.MINOR.PATCH`

- **MAJOR** (1.0.0 → 2.0.0): Breaking changes
- **MINOR** (1.0.0 → 1.1.0): New features (backward compatible)
- **PATCH** (1.0.0 → 1.0.1): Bug fixes

**Examples**:
- `v1.0.0` - Initial release
- `v1.0.1` - Bug fix
- `v1.1.0` - New feature (AI improvements)
- `v2.0.0` - Major redesign

---

## GitHub Secrets Required

| Secret | Description | How to Get |
|--------|-------------|------------|
| `GOOGLE_SERVICES_JSON` | Firebase config | Base64 encode `google-services.json` |

**Set up once**:
```bash
# Linux/Mac
base64 -w 0 app/android/app/google-services.json

# Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app\android\app\google-services.json"))
```

Add to: `Settings` → `Secrets and variables` → `Actions` → `New repository secret`

---

## What Gets Built

| Platform | File | Size | Time |
|----------|------|------|------|
| Android APK | `app-release.apk` | ~50 MB | 15 min |
| Android AAB | `app-release.aab` | ~40 MB | 15 min |
| iOS IPA | `app-release.ipa` | ~100 MB | 20 min |
| Web | `airo-web-release.zip` | ~30 MB | 10 min |
| Windows | `airo-windows-release.zip` | ~80 MB | 15 min |
| Linux | `airo-linux-release.tar.gz` | ~60 MB | 15 min |

**Total**: ~360 MB, ~20 minutes (parallel builds)

---

## Troubleshooting

### Build Fails
```bash
# Check GitHub Actions logs
# Go to: https://github.com/DevelopersCoffee/airo/actions

# Common fixes:
1. Verify GOOGLE_SERVICES_JSON secret is set
2. Check pubspec.yaml for errors
3. Ensure all dependencies are available
```

### Tag Already Exists
```bash
# Delete local tag
git tag -d v1.0.0

# Delete remote tag
git push origin :refs/tags/v1.0.0

# Create new tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Release Not Public
```bash
# Check if release is draft
# Go to: https://github.com/DevelopersCoffee/airo/releases
# Click "Edit" and uncheck "Draft"
```

---

## Sharing with Users

### Social Media Post Template
```
🎉 Airo Super App v1.0.0 is now available!

📱 Download for Android:
https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk

✨ Features:
- AI Chat Assistant
- Chess Game
- Music Player
- Multi-platform support

#AiroApp #Flutter #AI #OpenSource
```

### README Badge
```markdown
[![Download APK](https://img.shields.io/github/v/release/DevelopersCoffee/airo?label=Download%20APK&color=success)](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)
```

---

## Automated Release Script

Create `scripts/release.sh`:

```bash
#!/bin/bash
set -e

VERSION=$1

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  echo "Example: ./scripts/release.sh 1.0.0"
  exit 1
fi

echo "🚀 Creating release v$VERSION..."

# Update version in pubspec.yaml
sed -i "s/^version: .*/version: $VERSION+1/" app/pubspec.yaml

# Commit changes
git add app/pubspec.yaml
git commit -m "Bump version to $VERSION"
git push

# Create and push tag
git tag -a "v$VERSION" -m "Release v$VERSION"
git push origin "v$VERSION"

echo "✅ Release v$VERSION created!"
echo "📦 Build in progress: https://github.com/DevelopersCoffee/airo/actions"
echo "📥 Will be available at: https://github.com/DevelopersCoffee/airo/releases/tag/v$VERSION"
```

Make it executable:
```bash
chmod +x scripts/release.sh
```

---

## Monitoring Releases

### View Download Stats
```bash
# Using GitHub CLI
gh release view v1.0.0

# Using API
curl https://api.github.com/repos/DevelopersCoffee/airo/releases/latest
```

### Get Latest Version
```bash
# Using GitHub CLI
gh release list --limit 1

# Using API
curl -s https://api.github.com/repos/DevelopersCoffee/airo/releases/latest | grep tag_name
```

---

## Best Practices

1. ✅ **Test locally** before releasing
2. ✅ **Update CHANGELOG.md** with changes
3. ✅ **Create release notes** in RELEASE_NOTES.md
4. ✅ **Use semantic versioning** (MAJOR.MINOR.PATCH)
5. ✅ **Tag with descriptive messages**
6. ✅ **Wait for CI to pass** before tagging
7. ✅ **Announce releases** on social media
8. ✅ **Monitor download stats**

---

## Quick Commands

```bash
# View current version
grep "^version:" app/pubspec.yaml

# List all tags
git tag -l

# View latest release
gh release view --web

# Delete a release
gh release delete v1.0.0

# Create draft release
gh release create v1.0.0 --draft --title "v1.0.0" --notes "Release notes"
```

---

## Support

- **Documentation**: [Full Publishing Guide](./GITHUB_APK_PUBLISHING_GUIDE.md)
- **Issues**: https://github.com/DevelopersCoffee/airo/issues
- **Discussions**: https://github.com/DevelopersCoffee/airo/discussions

---

**Happy Releasing! 🎉**

