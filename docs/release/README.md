# 📦 Releases & Changelogs

Documentation for Airo releases and version history.

---

## 📋 Changelogs

| Version | Date | Highlights |
|---------|------|------------|
| [Airo TV v0.0.1](./AIRO_TV_v0.0.1.md) | 2026-07-14 | Android TV IPTV release, Play Store readiness, Cast diagnostics |
| [v1.1.0](./CHANGELOG_v1.1.0.md) | 2025-11-29 | Bill Split, E2E Testing, OCR Integration |
| [v1.0.0](./RELEASE_v1.0.0_SUMMARY.md) | 2025-11-11 | Initial public release |

---

## 🚀 Latest Release: Airo TV v0.0.1

### New Features
- **Airo TV** - Android TV package `io.airo.app.tv` from the v2 release line
- **IPTV playlists** - Bring-your-own authorized M3U import, channel search, and playback
- **Cast controls** - Pause/play/stop/reload/new session/volume states plus network diagnostics
- **Play Store readiness** - Leanback launcher, Pixel/mobile fallback layout, accessibility labels, and legal content notes

### Quick Links
- [Airo TV v0.0.1 Notes](./AIRO_TV_v0.0.1.md)
- [GitHub Releases](https://github.com/DevelopersCoffee/airo/releases)
- [Download Latest APK](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)

---

## 📚 Release Documentation

| Document | Description |
|----------|-------------|
| [Airo TV v0.0.1](./AIRO_TV_v0.0.1.md) | Release notes, Play Store readiness, artifact checklist |
| [Airo V1 and V2 Version Lines](./VERSION_LINES.md) | Base branch, tag, artifact, and support policy for monolith V1 and modular V2 |
| [Changelog v1.1.0](./CHANGELOG_v1.1.0.md) | Current version changes |
| [Release v1.0.0 Summary](./RELEASE_v1.0.0_SUMMARY.md) | Initial release details |
| [Publishing Guide](./GITHUB_APK_PUBLISHING_GUIDE.md) | How to publish APKs |
| [Quick Release Guide](./QUICK_RELEASE_GUIDE.md) | Fast release checklist |
| [Publishing Summary](./PUBLISHING_SUMMARY.md) | Publishing overview |

## 📋 QA & Compliance

| Document | Description |
|----------|-------------|
| [Release Checklist](./RELEASE_CHECKLIST.md) | Pre-release verification |
| [Store Compliance](./STORE_COMPLIANCE.md) | Play Store/App Store guidelines |
| [Rollback Procedure](./ROLLBACK_PROCEDURE.md) | Emergency rollback steps |
| [Beta Testing](./BETA_TESTING.md) | Beta coordination guide |

---

## 🔗 External Links

- **GitHub Releases**: https://github.com/DevelopersCoffee/airo/releases
- **GitHub Actions**: https://github.com/DevelopersCoffee/airo/actions
- **Latest APK**: https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk

---

## 📝 Creating a New Release

```bash
# Using the release script
./scripts/release.sh 1.2.0

# Or manually
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin v1.2.0
```

See [Quick Release Guide](./QUICK_RELEASE_GUIDE.md) for detailed instructions.
