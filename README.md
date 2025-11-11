# Airo Super App

[![Download APK](https://img.shields.io/github/v/release/DevelopersCoffee/airo?label=Download%20APK&color=success)](https://github.com/DevelopersCoffee/airo/releases/latest/download/app-release.apk)
[![GitHub Release](https://img.shields.io/github/v/release/DevelopersCoffee/airo)](https://github.com/DevelopersCoffee/airo/releases)
[![License](https://img.shields.io/github/license/DevelopersCoffee/airo)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.24.0+-blue.svg)](https://flutter.dev/)

A Flutter-based super app combining AI-powered features and financial management tools.

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
- **Flutter SDK**: 3.24.0 or later
- **Dart SDK**: 3.5.0 or later

### Platform-Specific Requirements

#### Android Development
- **Android Studio**: Latest version
- **Android SDK**: API 24-35
- **Java**: JDK 17 or later
- **Gradle**: 8.0 or later

#### iOS Development (macOS only)
- **Xcode**: 15.0 or later
- **iOS SDK**: 12.0 or later
- **CocoaPods**: Latest version

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
