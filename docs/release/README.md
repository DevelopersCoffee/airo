# 📦 Releases & Changelogs

Documentation for Airo releases and version history.

---

## 📋 Changelogs

| Version | Date | Highlights |
|---------|------|------------|
| [v1.1.0](./CHANGELOG_v1.1.0.md) | 2025-11-29 | Bill Split, E2E Testing, OCR Integration |
| [v1.0.0](./RELEASE_v1.0.0_SUMMARY.md) | 2025-11-11 | Initial public release |

---

## 🚀 Latest Release: v1.1.0

### New Features
- **Bill Split** - Splitwise-style expense splitting with OCR
- **E2E Testing** - Playwright + Patrol test infrastructure
- **Receipt Scanning** - ML Kit + Gemini Nano hybrid OCR
- **WhatsApp Sharing** - Formatted itemized summaries

### Quick Links
- [Full Changelog v1.1.0](./CHANGELOG_v1.1.0.md)
- [GitHub Releases](https://github.com/DevelopersCoffee/airo/releases)
- [Download Latest APK](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)

---

## 📚 Release Documentation

| Document | Description |
|----------|-------------|
| [Changelog v1.1.0](./CHANGELOG_v1.1.0.md) | Current version changes |
| [Release v1.0.0 Summary](./RELEASE_v1.0.0_SUMMARY.md) | Initial release details |
| [Publishing Guide](./GITHUB_APK_PUBLISHING_GUIDE.md) | How to publish APKs |
| [Quick Release Guide](./QUICK_RELEASE_GUIDE.md) | Fast release checklist |
| [Publishing Summary](./PUBLISHING_SUMMARY.md) | Publishing overview |

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

