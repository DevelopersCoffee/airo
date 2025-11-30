# App Signing Setup Guide

This document explains how to set up code signing for Android and iOS releases.

## Required GitHub Secrets

### Android Signing

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded .jks keystore file |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias in the keystore |
| `ANDROID_KEY_PASSWORD` | Key password |

### iOS Signing

| Secret | Description |
|--------|-------------|
| `IOS_P12_BASE64` | Base64-encoded .p12 distribution certificate |
| `IOS_P12_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_PROFILE_BASE64` | Base64-encoded provisioning profile |

## Android Setup

### 1. Generate Keystore

```bash
keytool -genkey -v -keystore airo-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias airo-key \
  -storepass YOUR_STORE_PASSWORD \
  -keypass YOUR_KEY_PASSWORD
```

### 2. Encode Keystore to Base64

```bash
# macOS/Linux
base64 -i airo-release-key.jks | pbcopy

# Windows (PowerShell)
[Convert]::ToBase64String([IO.File]::ReadAllBytes("airo-release-key.jks")) | Set-Clipboard
```

### 3. Configure app/android/app/build.gradle

```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 4. Add Secrets to GitHub

1. Go to Repository → Settings → Secrets and variables → Actions
2. Add each secret with the correct value

## iOS Setup

### 1. Export Distribution Certificate

1. Open Keychain Access
2. Find your Apple Distribution certificate
3. Right-click → Export → Save as .p12

### 2. Encode Certificate to Base64

```bash
base64 -i certificate.p12 | pbcopy
```

### 3. Export Provisioning Profile

1. Download from Apple Developer Portal
2. Encode to base64:
```bash
base64 -i profile.mobileprovision | pbcopy
```

### 4. Add Secrets to GitHub

Same as Android - add each secret to repository settings.

## Staged Rollout Configuration

### Play Store Internal Track

The workflow creates signed AAB files ready for Play Store upload.

1. Use `fastlane` or manual upload to Play Console
2. Release to Internal Testing track first
3. Promote to production with percentage rollout

### TestFlight

1. Upload IPA to App Store Connect
2. TestFlight will process the build
3. Add internal/external testers
4. Promote to production when ready

## Security Best Practices

1. **Never commit signing keys** to the repository
2. **Rotate keys** if compromised
3. **Use different keys** for debug and release
4. **Enable key backup** in secure location
5. **Document key recovery** procedures

## Troubleshooting

### Android: "keystore not found"
- Verify `ANDROID_KEYSTORE_BASE64` is correctly encoded
- Check the base64 doesn't have newlines

### iOS: "certificate not found"
- Verify certificate hasn't expired
- Check provisioning profile matches bundle ID
- Ensure Team ID is correct

### Build fails with signing errors
- Check all 4 secrets are set correctly
- Verify passwords don't contain special characters that need escaping

