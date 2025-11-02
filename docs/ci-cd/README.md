# 🔄 CI/CD Pipeline

Complete guide to the Airo Super App CI/CD pipeline.

---

## 📖 Documentation

### [CI_CD_SETUP.md](./CI_CD_SETUP.md)
**Initial CI/CD setup** guide:
- GitHub Actions configuration
- Workflow setup
- Secret management
- First build

### [CI_CD_COMPLETE.md](./CI_CD_COMPLETE.md)
**Complete pipeline overview**:
- All workflows explained
- Build matrix
- Release process
- Troubleshooting

### [CI_CD_SUMMARY.md](./CI_CD_SUMMARY.md)
**Quick summary** of the pipeline:
- What's included
- How it works
- Key features
- Next steps

### [CI_CD_CHECKLIST.md](./CI_CD_CHECKLIST.md)
**Setup verification checklist**:
- Pre-setup checks
- Setup steps
- Verification steps
- Troubleshooting

### [RELEASE_GUIDE.md](./RELEASE_GUIDE.md)
**How to create releases**:
- Release process
- Version numbering
- Release notes
- Asset management

---

## 🎯 Quick Start

### 1. Setup CI/CD
Read [CI_CD_SETUP.md](./CI_CD_SETUP.md)

### 2. Verify Setup
Follow [CI_CD_CHECKLIST.md](./CI_CD_CHECKLIST.md)

### 3. Create Release
Follow [RELEASE_GUIDE.md](./RELEASE_GUIDE.md)

---

## 📊 Workflows

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| build-and-release | Tag push (v*) | Build all platforms |
| ci | Push to main | Run tests & analysis |
| pr-checks | Pull request | Validate PR |
| version-and-changelog | Manual | Bump version |

---

## 🔗 Links

- **GitHub Actions**: https://github.com/DevelopersCoffee/airo/actions
- **Releases**: https://github.com/DevelopersCoffee/airo/releases
- **GitHub Actions Docs**: https://docs.github.com/en/actions

---

**Ready?** → [Start with CI/CD Setup](./CI_CD_SETUP.md)

