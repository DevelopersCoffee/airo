# 📦 Releases & Changelogs

Documentation for Airo releases and version history.

---

## 📋 Changelogs

| Version | Date | Highlights |
|---------|------|------------|
| [Airo TV v0.0.2](./AIRO_TV_v0.0.2.md) | 2026-07-14 | Release trust update, checksums, clean assets, documentation |
| [Airo TV v0.0.1](./AIRO_TV_v0.0.1.md) | 2026-07-14 | Android TV IPTV release, Play Store readiness, Cast diagnostics |
| [v1.1.0](./CHANGELOG_v1.1.0.md) | 2025-11-29 | Bill Split, E2E Testing, OCR Integration |
| [v1.0.0](./RELEASE_v1.0.0_SUMMARY.md) | 2025-11-11 | Initial public release |

---

## Latest Release: Airo TV v0.0.2

### New Features
- **Release assets** - Clean APK/AAB filenames and SHA256 checksums
- **Release notes** - Mature open-source release format for Airo TV releases
- **Trust documentation** - Privacy, security, threat model, roadmap, feature matrix, and architecture docs
- **Play Store readiness** - Release process documents screenshots, demo video, legal notice, and known limitations

### Quick Links
- [Airo TV v0.0.2 Notes](./AIRO_TV_v0.0.2.md)
- [Airo TV Release Template](./AIRO_TV_RELEASE_TEMPLATE.md)
- [Airo TV Feature Matrix](./AIRO_TV_FEATURE_MATRIX.md)
- [Airo TV Media Assets](./AIRO_TV_MEDIA_ASSETS.md)
- [GitHub Releases](https://github.com/DevelopersCoffee/airo/releases)
- [Download Airo TV APK](https://github.com/DevelopersCoffee/airo/releases/download/airo-tv-v0.0.2/Airo-TV-v0.0.2.apk)
- [Verify direct APK downloads](../../VERIFY_DOWNLOAD.md)
- [Trust and transparency](../../TRUST.md)

---

## 📚 Release Documentation

| Document | Description |
|----------|-------------|
| [Airo TV v0.0.2](./AIRO_TV_v0.0.2.md) | Professional release notes, checksums, limitations, installation |
| [Airo TV v0.0.1](./AIRO_TV_v0.0.1.md) | Release notes, Play Store readiness, artifact checklist |
| [Airo TV Release Template](./AIRO_TV_RELEASE_TEMPLATE.md) | Stable release format for future Airo TV versions |
| [Airo TV Feature Matrix](./AIRO_TV_FEATURE_MATRIX.md) | Supported, planned, and unsupported features |
| [Airo TV Media Assets](./AIRO_TV_MEDIA_ASSETS.md) | Screenshot and demo-video release checklist |
| [Airo V1 and V2 Version Lines](./VERSION_LINES.md) | Base branch, tag, artifact, and support policy for monolith V1 and modular V2 |
| [V2 Distribution Matrix](./V2_DISTRIBUTION_MATRIX.md) | Supported v2 profiles, artifact naming, channels, and support policy |
| [V2 Publishing Human Setup](./V2_PUBLISHING_HUMAN_SETUP.md) | Account, credential, signing, store, and governance decisions maintainers must complete |
| [V2 License Review](./V2_LICENSE_REVIEW.md) | License-readiness baseline and maintainer decisions before public distribution |
| [V2 Release Qualification](./V2_RELEASE_QUALIFICATION.md) | Required release evidence, device matrix, waiver behavior, and qualification report format |
| [V2 Release Orchestrator](./V2_RELEASE_ORCHESTRATOR.md) | Top-level v2 release workflow, dry-run behavior, TV workflow reuse, and remaining publishing blockers |
| [Download Verification](../../VERIFY_DOWNLOAD.md) | SHA256 verification and safe direct APK install guidance |
| [Trust and Transparency](../../TRUST.md) | Public trust boundaries for content, telemetry, accounts, and release artifacts |
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
- **Airo TV APK**: https://github.com/DevelopersCoffee/airo/releases/download/airo-tv-v0.0.2/Airo-TV-v0.0.2.apk

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
