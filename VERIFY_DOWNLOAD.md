# Verify Airo Downloads

Use this guide before installing APKs downloaded from GitHub Releases. It is
written for Airo v2 release artifacts, including mobile, tablet, Android TV, and
Fire TV builds when those profiles are published.

## 1. Download From The Release Page

Download APKs only from the official Airo release page:

<https://github.com/DevelopersCoffee/airo/releases>

For each release, download:

- the APK that matches your device profile;
- `SHA256SUMS`;
- the release notes or release manifest, when available.

Do not install APKs mirrored from chat apps, file-sharing sites, or unofficial
web pages.

## 2. Choose The Right Artifact

Release artifact names should identify the app profile and version.

| Device | Expected artifact |
| --- | --- |
| Android phone | Mobile Android APK or Play Store install |
| Android tablet | Mobile/tablet Android APK or Play Store install |
| Android TV / Google TV | Airo TV APK or Play Store TV install |
| Fire TV | Airo TV / Fire TV compatible APK when listed as supported |

If a release does not list your device class, treat that device as unsupported
for that release.

## 3. Verify SHA256

Open a terminal in the folder containing the downloaded APK and `SHA256SUMS`.

### macOS

```bash
shasum -a 256 Airo-TV-v0.0.2.apk
cat SHA256SUMS
```

### Linux

```bash
sha256sum Airo-TV-v0.0.2.apk
cat SHA256SUMS
```

### Windows PowerShell

```powershell
Get-FileHash .\Airo-TV-v0.0.2.apk -Algorithm SHA256
Get-Content .\SHA256SUMS
```

The hash printed for your APK must exactly match the matching entry in
`SHA256SUMS`. Do not install the APK if the hash differs.

## 4. Check The Release Source

Before installing, confirm:

- the file is attached to a release in `DevelopersCoffee/airo`;
- the release notes match the version in the APK filename;
- the release manifest lists the same filename, package ID, profile, and
  SHA256 checksum when a manifest is published;
- the release is not marked as withdrawn or known-bad;
- the artifact profile matches your device.

## 5. Install Safely

Android may warn when installing APKs outside the Play Store. That warning is
expected for direct APK installs, but it does not replace checksum verification.

Do not install if:

- the APK came from an unofficial source;
- `SHA256SUMS` is missing for a public direct-download release;
- the checksum does not match;
- the release notes do not mention your device profile;
- your device shows a different package name than the release notes describe.

## 6. Report Problems

Open a GitHub issue for install or verification problems:

<https://github.com/DevelopersCoffee/airo/issues>

Do not include private playlist URLs, credentials, tokens, local network
addresses, or screenshots containing sensitive data.
