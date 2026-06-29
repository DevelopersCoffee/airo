# Airo Super App

[![Download APK](https://img.shields.io/github/v/release/DevelopersCoffee/airo?label=Download%20APK&color=success)](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)
[![GitHub Release](https://img.shields.io/github/v/release/DevelopersCoffee/airo)](https://github.com/DevelopersCoffee/airo/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.44.4+-blue.svg)](https://flutter.dev/)

Airo is a local-first Flutter app exploring an on-device "LLM OS" direction:
AI chat, media workflows, finance tooling, routines, and native mobile
capabilities in one repo.

This repository is meant to be understandable by contributors, not only end
users downloading a release build.

## Open Source Contributor Start

- Contribution guide: [CONTRIBUTING.md](CONTRIBUTING.md)
- Community standards: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Agent workflow policy: [AGENTS.md](AGENTS.md)
- User and operator docs: [docs/wiki/README.md](docs/wiki/README.md)
- Scoped engineering tickets: [.github/issues](.github/issues)

Why developers care:

- The repo mixes Flutter UI, native Android/iOS integration, Riverpod state,
  and deterministic repo policy around issues, contracts, and tests.
- Airo is intentionally local-first, so on-device constraints and privacy
  boundaries matter in real implementation work.
- Many tasks are already decomposed into scoped tickets that can be landed
  independently from fresh worktrees.

Quick contributor bootstrap:

```bash
git fetch origin main
git worktree add ../airo-my-task -b codex/my-task origin/main
cd ../airo-my-task
make setup
make analyze
make test
```

Before writing code, confirm the linked issue has a Critical Agent Gate and any
required Feature Packet content. If it does not, add that policy context first.

## Contribution Paths

- Docs and onboarding: improve README, wiki pages, setup instructions, or
  release/developer guidance.
- Focused product work: pick a scoped issue with ownership and deterministic
  verification already described.
- Native/runtime fixes: keep the change narrow, report exact validation, and
  avoid cross-boundary edits without the required contract.

## Pull Request Expectations

- Link the issue being addressed.
- Start from the latest `origin/main` in a fresh branch or worktree.
- Run the narrowest honest verification locally and report what was blocked.
- Update docs/wiki when user-facing behavior changes.
- Use the existing PR template and keep the branch scoped to one concern.

## 📥 Download

### Android
**[⬇️ Download Latest APK](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)** (~50 MB)

### iOS
**[⬇️ Download Latest IPA](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.ipa)** (~100 MB)

### Web
**[⬇️ Download Web Build](https://github.com/DevelopersCoffee/airo/releases/latest/download/airo-web-release.zip)** (~30 MB)

### All Platforms
**[📦 View All Releases](https://github.com/DevelopersCoffee/airo/releases)**

---

## 🚀 Quick Start

### First-time Setup (Newly Cloned Repo)

```bash
# Complete setup for all platforms
make setup

# Or setup for specific platform
make setup-android  # Android development
make setup-ios      # iOS development (macOS only)
make setup-web      # Web development
```

### Development

```bash
# Run on different platforms
make run-android    # Android device/emulator
make run-ios        # iOS device/simulator
make run-web        # Web browser
make run-chrome     # Chrome browser specifically

# Platform-specific optimized runs
make run-pixel9     # Optimized for Pixel 9
make run-iphone13   # iPhone 13 Pro Max simulator
```

## Contributor Workflow

1. Choose an issue with clear scope.
2. Create a fresh worktree from `origin/main`.
3. Run `make setup`, then relevant verification such as `make analyze` and
   `make test`.
4. Follow [AGENTS.md](AGENTS.md) for Critical Agent Gate and cross-agent policy
   requirements.
5. Open a PR with summary, risks, verification, and docs impact.

For the complete process, including docs-only contributions and maintainer
expectations, see [CONTRIBUTING.md](CONTRIBUTING.md).

## 📱 Platform Support

### ✅ Supported Platforms

- **Android**: API 24+ (Android 7.0+)
  - ⭐ **Pixel 9**: Fully optimized with Gemini Nano support
  - Supports all modern Android devices
- **iOS**: iOS 12.0+
  - ⭐ **iPhone 13 Pro Max**: Fully optimized for iOS 18
  - Supports all modern iPhone and iPad devices
- **Web**: Modern browsers
  - ⭐ **Chrome**: Fully optimized with PWA support
  - Firefox, Safari, Edge supported

### 🎯 Target Devices

- **Pixel 9**: Android 15 (API 35) with Gemini Nano AI features
- **iPhone 13 Pro Max**: iOS 18 with advanced AI capabilities
- **Chrome Browser**: PWA with offline support

## 🏗️ Architecture

### Super App Structure
```
airo_super_app/
├── app/                    # Main host application
│   ├── lib/
│   │   ├── core/          # Core app functionality
│   │   ├── features/      # App-specific features
│   │   └── shared/        # Shared widgets and utilities
├── packages/
│   ├── airo/              # AI-powered features package
│   └── airomoney/         # Financial management package
└── Makefile               # Build automation
```

### Features

#### 🤖 Airo Package (AI Features)
- AI Chat Interface
- Voice Commands
- Task Management
- Analytics Dashboard

#### 💰 AiroMoney Package (Financial Management)
- Wallet Management
- Transaction Tracking
- Financial Analytics
- Budget Planning

## 🛠️ Development Commands

### Setup & Installation
```bash
make help           # Show all available commands
make setup          # Complete first-time setup
make install-deps   # Install dependencies only
make check-flutter  # Verify Flutter installation
```

### Running the App
```bash
make run-android    # Run on Android
make run-ios        # Run on iOS (macOS only)
make run-web        # Run on web
make run-chrome     # Run on Chrome specifically
make run-pixel9     # Run optimized for Pixel 9
make run-iphone13   # Run on iPhone 13 Pro Max simulator
```

### Building
```bash
make build-android  # Build Android APK
make build-ios      # Build iOS app (macOS only)
make build-web      # Build web app
make build-all      # Build for all platforms
```

### Testing & Quality
```bash
make test           # Run all tests
make analyze        # Analyze code
make format         # Format code
make doctor         # Run Flutter doctor
```

### Maintenance
```bash
make clean          # Clean build artifacts
make upgrade        # Upgrade Flutter and dependencies
make devices        # List available devices
make emulators      # List available emulators
```

## 📋 Prerequisites

### Required
- **Flutter SDK**: 3.44.4 or later
- **Dart SDK**: 3.12.2 or later

### Platform-Specific Requirements

#### Android Development
- **Android Studio**: Latest version
- **Android SDK**: API 24-35
- **Java**: JDK 17 or later
- **Gradle**: 8.0 or later

#### iOS Development (macOS only)
- **Xcode**: 15.0 or later
- **iOS SDK**: 12.0 or later
- **CocoaPods**: Required for Flutter plugins that still ship via podspec
- **Swift Package Manager**: Used by the Flutter engine where supported

#### Web Development
- **Chrome**: Latest version (recommended)
- **Web Server**: Built-in Flutter web server

## 🔧 Configuration

### Environment Variables
```bash
# Android
export ANDROID_HOME=/path/to/android/sdk
export ANDROID_SDK_ROOT=$ANDROID_HOME

# iOS (macOS only)
export PATH=$PATH:/Applications/Xcode.app/Contents/Developer/usr/bin
```

### Platform-Specific Settings

#### Android (Pixel 9 Optimization)
- **Target SDK**: 35 (Android 15)
- **Min SDK**: 24 (Android 7.0)
- **Compile SDK**: 35
- **NDK**: Latest version
- **Multidex**: Enabled
- **Gemini Nano**: Integrated for AI features

#### Android Release Signing
Release APKs and AABs must be signed with a private release keystore. Debug keys are never used for release builds.

For local release builds:

```bash
cd app/android
cp key.properties.example key.properties
# Put your release keystore at app/android/release.keystore, or update storeFile.
# Fill in storePassword, keyAlias, and keyPassword in key.properties.
cd ../..
flutter build apk --release
```

Never commit `app/android/key.properties` or keystore files. They are ignored by `.gitignore`.

For GitHub Actions releases, configure these repository secrets:

- `ANDROID_RELEASE_KEYSTORE_BASE64`: base64-encoded release keystore file
- `KEYSTORE_PASSWORD`: keystore password
- `KEY_ALIAS`: release key alias
- `KEY_PASSWORD`: release key password

Generate and encode a new keystore with:

```bash
keytool -genkeypair \
  -v \
  -keystore release.keystore \
  -alias airo-release \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
base64 -i release.keystore | tr -d '\n' > release.keystore.base64
```

#### iOS (iPhone 13 Pro Max Optimization)
- **Deployment Target**: 12.0
- **Target**: iOS 18
- **Architecture**: arm64
- **Bitcode**: Disabled (as per Apple requirements)

#### Web (Chrome Optimization)
- **Renderer**: CanvasKit (for better performance)
- **PWA**: Enabled
- **Service Worker**: Enabled for offline support

## 🚀 Getting Started

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd airo_super_app
   ```

2. **Run first-time setup**
   ```bash
   make setup
   ```

3. **Start development**
   ```bash
   # For Android (including Pixel 9)
   make dev-android
   
   # For iOS (including iPhone 13 Pro Max)
   make dev-ios
   
   # For Web (including Chrome)
   make dev-web
   ```

## 📱 Authentication

The app includes a common authentication system:

- **Admin Login**: 
  - Username: `admin`
  - Password: `admin`
- **User Registration**: Username and password only (minimal design)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Format code: `make format`
6. Analyze code: `make analyze`
7. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Troubleshooting

### Common Issues

1. **Flutter not found**
   ```bash
   # Install Flutter from https://flutter.dev/docs/get-started/install
   make check-flutter
   ```

2. **Android SDK issues**
   ```bash
   # Set ANDROID_HOME environment variable
   export ANDROID_HOME=/path/to/android/sdk
   make setup-android
   ```

3. **iOS build issues (macOS only)**
   ```bash
   # Install Xcode and command line tools
   xcode-select --install
   make setup-ios
   ```

4. **Web build issues**
   ```bash
   # Enable web support
   flutter config --enable-web
   make setup-web
   ```

### Getting Help

- Run `make help` for available commands
- Run `make doctor` to check your development environment
- Check Flutter documentation: https://flutter.dev/docs
