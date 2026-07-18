# Security Checklist - Before Pushing to GitHub

## ✅ Sensitive Files Removed

- [x] `google-services.json` - Firebase configuration with API keys
  - **Status**: Excluded from git tracking
  - **Template**: `app/android/app/google-services.json.template`
  - **Action**: Use template to create local copy

- [x] `app/lib/firebase_options.dart` - Dart-side FlutterFire config (web/android/iOS/macOS/windows)
  - **Status**: Excluded from git tracking (2026-07-19)
  - **Template**: `app/lib/firebase_options.dart.template`
  - **Action**: Copy the template to `app/lib/firebase_options.dart` and fill in real
    `web`/`android`/`androidTv` values from the Firebase Console. Leave the
    `androidStreaming`/`ios`/`macos`/`windows` entries as placeholders until those
    apps are registered -- `DefaultFirebaseOptions.isCurrentPlatformConfigured`
    already skips Firebase init for any placeholder appId.
  - **CI**: `airo-tv-release.yml`, `airo-mobile-tablet-release.yml`, and
    `build-and-release.yml` write the real file from a base64-encoded
    `FIREBASE_OPTIONS_DART_B64` repository secret, falling back to the
    checked-in placeholder template when the secret isn't set (same pattern as
    `GOOGLE_SERVICES_JSON`).
  - **Note**: Firebase client API keys are not secret by Google's own design --
    the actual security boundary is Firebase Security Rules, App Check, and
    API key restrictions in the GCP Console, not repo secrecy. This change is
    about git hygiene and matching the existing `google-services.json`
    pattern, not closing an exploitable hole.
  - **Follow-up**: `FIREBASE_OPTIONS_DART_B64` repo secret still needs to be
    provisioned (org-admin action) -- until then, CI/release builds fall back
    to the placeholder template and Firebase init is skipped at runtime.

## ✅ Gitignore Updated

- [x] Added `google-services.json` to `.gitignore`
- [x] Added `*.key`, `*.pem`, `*.p12`, `*.jks`, `*.keystore`
- [x] Added `.env` and environment files
- [x] Added `secrets.json`, `credentials.json`
- [x] Added `local.properties`
- [x] Added Firebase debug logs
- [x] Added API key files

## ✅ Hardcoded Credentials - FIXED

### Environment-Based Demo Credentials

**Status**: ✅ IMPLEMENTED - Environment-based configuration

Demo credentials are now controlled via build-time environment variables:

**Configuration File**: `app/lib/core/config/app_config.dart`
```dart
// Build with: flutter run --dart-define=ENV=prod --dart-define=DEMO_MODE=false
static const String environment = String.fromEnvironment('ENV', defaultValue: 'dev');
static const bool isDemoMode = bool.fromEnvironment('DEMO_MODE', defaultValue: true);
```

**Auth Service**: `app/lib/core/auth/auth_service.dart`
```dart
class DemoCredentials {
  static const String _demoUsername = String.fromEnvironment('DEMO_USERNAME', defaultValue: 'demo');
  static const String _demoPassword = String.fromEnvironment('DEMO_PASSWORD', defaultValue: 'demo123');
  static bool get isEnabled => AppConfig.isDemoMode && !AppConfig.isProd;
}
```

**Security Features**:
- ✅ Demo credentials only work in dev/demo mode
- ✅ Production builds (`ENV=prod`) disable demo login entirely
- ✅ Credentials can be customized per build via `--dart-define`
- ✅ UI elements (demo button, credentials display) hidden in production
- ✅ No hardcoded `admin/admin` in codebase

**Build Commands**:
```bash
# Development (demo enabled)
flutter run --dart-define=ENV=dev --dart-define=DEMO_MODE=true

# Production (demo disabled)
flutter run --dart-define=ENV=prod --dart-define=DEMO_MODE=false

# Custom demo credentials
flutter run --dart-define=DEMO_USERNAME=tester --dart-define=DEMO_PASSWORD=test123
```

## 🔐 Security Best Practices

### Before Each Push

1. **Check for Secrets**
   ```bash
   git diff --cached | grep -i "password\|secret\|key\|token"
   ```

2. **Verify No Sensitive Files**
   ```bash
   git status | grep -E "\.key|\.pem|\.env|secrets"
   ```

3. **Review Staged Changes**
   ```bash
   git diff --cached --name-only
   ```

### Environment Variables

Create `.env.local` (NOT committed):
```
FIREBASE_API_KEY=your_key_here
ADMIN_PASSWORD=your_password_here
```

### Production Deployment

1. **Remove hardcoded credentials**
2. **Use environment variables**
3. **Enable code obfuscation**
4. **Use Firebase Security Rules**
5. **Enable API key restrictions**

## 📋 Files to Never Commit

- `google-services.json` - Firebase config
- `.env` files - Environment variables
- `*.key`, `*.pem` - Private keys
- `secrets.json` - API secrets
- `credentials.json` - Service account keys
- `local.properties` - Local build config
- IDE settings with credentials

## ✅ Verified Safe Files

- [x] `.vscode/settings.json` - No sensitive data
- [x] `pubspec.yaml` - No API keys
- [x] `android/gradle.properties` - No secrets
- [x] `ios/Runner/Info.plist` - No secrets
- [x] All Dart source files - No hardcoded secrets (except dev defaults)

## 🚀 Ready to Push

**Status**: ✅ SAFE TO PUSH

All sensitive information has been:
- Removed from git tracking
- Added to `.gitignore`
- Documented with templates
- Marked for local configuration

## 📝 Setup Instructions for New Developers

1. **Clone the repository**
   ```bash
   git clone git@github.com:DevelopersCoffee/airo.git
   ```

2. **Create local configuration files**
   ```bash
   # Firebase configuration
   cp app/android/app/google-services.json.template app/android/app/google-services.json
   # Edit with your Firebase credentials
   ```

3. **Create environment file** (if needed)
   ```bash
   cp .env.template .env.local
   # Edit with your local settings
   ```

4. **Build and run**
   ```bash
   cd app
   flutter pub get
   flutter run
   ```

## 🔍 Continuous Security

### Pre-commit Hook (Optional)

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash
# Prevent committing sensitive files
if git diff --cached | grep -E "password|secret|api_key|token"; then
  echo "ERROR: Sensitive data detected in commit!"
  exit 1
fi
```

### GitHub Actions (Optional)

Add secret scanning to CI/CD pipeline to detect leaked credentials.

## 📞 Incident Response

If sensitive data is accidentally committed:

1. **Immediately revoke credentials**
   - Regenerate Firebase API keys
   - Reset admin passwords
   - Revoke any exposed tokens

2. **Remove from history**
   ```bash
   git filter-branch --tree-filter 'rm -f app/android/app/google-services.json' HEAD
   git push --force-with-lease
   ```

3. **Notify team members**
   - Alert about the incident
   - Provide new credentials
   - Update documentation

## ✅ Final Verification

Before pushing to GitHub:

```bash
# Check for sensitive patterns
git diff --cached | grep -iE "password|secret|api.?key|token|credential"

# Verify no sensitive files
git status | grep -E "\.key|\.pem|\.env|secrets|google-services"

# Review all staged files
git diff --cached --name-only
```

**All checks passed**: ✅ SAFE TO PUSH

---

**Last Updated**: November 1, 2025
**Status**: Ready for GitHub Push

