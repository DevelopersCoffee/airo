# 🚀 Airo Super App - Quick Start Guide v0.0.1

**Get started in 5 minutes!**

---

## 👥 FOR USERS

### Download & Install (2 minutes)

#### Android
```bash
1. Go to: https://github.com/DevelopersCoffee/airo/releases/tag/v0.0.1
2. Download: app-release.apk
3. Enable "Unknown Sources" in Settings > Security
4. Tap the APK file to install
5. Launch Airo!
```

#### iOS
```bash
1. Go to: https://github.com/DevelopersCoffee/airo/releases/tag/v0.0.1
2. Download: app-release.ipa
3. Use Xcode or Apple Configurator to install
4. Launch Airo!
```

#### Web
```bash
1. Go to: https://github.com/DevelopersCoffee/airo/releases/tag/v0.0.1
2. Download: airo-web-release.zip
3. Extract files
4. Open index.html in your browser
5. Start using Airo!
```

### First Steps (3 minutes)

1. **Launch Airo**
   - Open the app
   - Create account (optional)

2. **Explore Features**
   - **Quest**: Upload a PDF and ask questions
   - **Money**: Track your expenses
   - **Beats**: Listen to music
   - **Loot**: Browse deals
   - **Chess**: Play a game
   - **Reminders**: Set notifications

3. **Get Help**
   - Read: https://developercoffee.github.io/airo/getting-started/
   - Issues: https://github.com/DevelopersCoffee/airo/issues

---

## 👨‍💻 FOR DEVELOPERS

### Setup Development Environment (5 minutes)

#### Prerequisites
```bash
# Check Flutter
flutter --version

# Check Dart
dart --version

# Check Java
java -version

# Run doctor
flutter doctor
```

#### Clone & Setup
```bash
# Clone repository
git clone https://github.com/DevelopersCoffee/airo.git
cd airo

# Get dependencies
cd app
flutter pub get

# Build for your platform
flutter build apk      # Android
flutter build ios      # iOS
flutter build web      # Web
```

#### Run on Device
```bash
# Connect device
adb devices

# Run app
flutter run

# Run with verbose logging
flutter run -v
```

### Project Structure
```
airo/
├── app/                    # Flutter app
│   ├── lib/
│   │   ├── features/       # Feature modules
│   │   ├── models/         # Data models
│   │   ├── services/       # Business logic
│   │   ├── providers/      # Riverpod providers
│   │   └── main.dart       # Entry point
│   ├── test/               # Tests
│   └── pubspec.yaml        # Dependencies
├── docs/                   # Documentation
├── .github/
│   └── workflows/          # CI/CD workflows
└── Makefile                # Build commands
```

### Common Commands
```bash
# Build
make build-release-all     # Build all platforms
make build-apk             # Build Android APK
make build-ios             # Build iOS IPA
make build-web             # Build Web

# Test
make test                  # Run tests
make test-coverage         # Run with coverage

# Quality
make analyze               # Analyze code
make lint                  # Lint code
make format                # Format code

# Release
make release-patch         # Create patch release
make release-minor         # Create minor release
make release-major         # Create major release
```

### Documentation
- **Architecture**: https://developercoffee.github.io/airo/architecture/
- **Features**: https://developercoffee.github.io/airo/features/
- **CI/CD**: https://developercoffee.github.io/airo/ci-cd/
- **Security**: https://developercoffee.github.io/airo/security/

---

## 🔄 FOR DEVOPS

### CI/CD Pipeline

#### Automated Workflows
- **CI**: Runs on every push
- **PR Checks**: Runs on pull requests
- **Release**: Runs on tag push (v*)
- **Quality**: SonarQube analysis
- **Security**: Snyk scanning

#### Create Release
```bash
# Create tag
git tag -a v0.0.2 -m "Release 0.0.2"

# Push tag
git push origin v0.0.2

# GitHub Actions will:
# 1. Build all platforms
# 2. Run tests
# 3. Scan code quality
# 4. Scan security
# 5. Create release
# 6. Upload executables
```

#### Monitor Builds
- **Actions**: https://github.com/DevelopersCoffee/airo/actions
- **SonarCloud**: https://sonarcloud.io/projects
- **Snyk**: https://app.snyk.io/org/ucguy4u/

### Documentation
- **CI/CD Setup**: https://developercoffee.github.io/airo/ci-cd/CI_CD_SETUP.md
- **Release Guide**: https://developercoffee.github.io/airo/ci-cd/RELEASE_GUIDE.md
- **Security**: https://developercoffee.github.io/airo/security/

---

## 📚 DOCUMENTATION

### Main Documentation
**https://developercoffee.github.io/airo**

### Quick Links
- **Getting Started**: https://developercoffee.github.io/airo/getting-started/
- **CI/CD**: https://developercoffee.github.io/airo/ci-cd/
- **Security**: https://developercoffee.github.io/airo/security/
- **Architecture**: https://developercoffee.github.io/airo/architecture/
- **Features**: https://developercoffee.github.io/airo/features/
- **Troubleshooting**: https://developercoffee.github.io/airo/troubleshooting/

---

## 🔗 IMPORTANT LINKS

### Repository
- **GitHub**: https://github.com/DevelopersCoffee/airo
- **Releases**: https://github.com/DevelopersCoffee/airo/releases
- **Issues**: https://github.com/DevelopersCoffee/airo/issues
- **Actions**: https://github.com/DevelopersCoffee/airo/actions

### Dashboards
- **SonarCloud**: https://sonarcloud.io/projects
- **Snyk**: https://app.snyk.io/org/ucguy4u/

---

## ❓ TROUBLESHOOTING

### Build Issues
```bash
# Clear cache
flutter clean
flutter pub get

# Check environment
flutter doctor -v

# Run with verbose
flutter run -v
```

### Common Errors
- **"Flutter not found"** → Install Flutter
- **"Java version error"** → Install Java 17+
- **"Android SDK not found"** → Run `flutter doctor`

### Get Help
1. Check: https://developercoffee.github.io/airo/troubleshooting/
2. Search: https://github.com/DevelopersCoffee/airo/issues
3. Create: https://github.com/DevelopersCoffee/airo/issues/new

---

## 🎉 YOU'RE READY!

### Next Steps
1. ✅ Download/Clone
2. ✅ Install/Setup
3. ✅ Launch/Run
4. ✅ Explore/Develop
5. ✅ Share/Contribute

---

**Questions?** → https://github.com/DevelopersCoffee/airo/issues

**Version**: 0.0.1
**Date**: November 2, 2025

