# Secrets Setup Guide

## Google Services Configuration

### Local Development Setup

1. **Get your Firebase configuration:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: `devscoffee-airo`
   - Navigate to Project Settings > General
   - Under "Your apps", find the Android app (`io.airo.app`)
   - Download `google-services.json`

2. **Place the file (local development):**
   ```bash
   cp /path/to/downloaded/google-services.json app/android/app/google-services.json
   ```

3. **Verify the file structure:**
   - Use `google-services.json.example` as a reference
   - Ensure package_name is `io.airo.app` (primary) or `com.airo.superapp` (legacy)
   - The file supports multiple package names for different build variants
   - Never commit the actual `google-services.json` file

### GitHub Secrets Setup (CI/CD)

The `google-services.json` file is gitignored for security. For CI/CD builds:

1. **Encode the file to Base64:**

   **Linux/macOS:**
   ```bash
   ./scripts/encode-google-services.sh
   ```

   **Windows PowerShell:**
   ```powershell
   .\scripts\encode-google-services.ps1
   ```

   **Manual (Linux/macOS):**
   ```bash
   base64 -w 0 app/android/app/google-services.json
   ```

2. **Add to GitHub Secrets:**
   - Go to: https://github.com/DevelopersCoffee/airo/settings/secrets/actions
   - Click "New repository secret"
   - Name: `GOOGLE_SERVICES_JSON`
   - Value: Paste the Base64 encoded string
   - Click "Add secret"

3. **CI/CD Workflow:**
   The workflows automatically decode the secret:
   ```yaml
   - name: Decode Google Services JSON
     env:
       GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
     run: |
       echo "$GOOGLE_SERVICES_JSON" | base64 -d > app/android/app/google-services.json
   ```

### Firebase Features Enabled

- ✅ Google Sign-In (Authentication)
- ✅ Firestore Database
- ⬜ Cloud Functions (planned)
- ⬜ Cloud Messaging (planned)

### Security Notes

- ✅ `google-services.json` is in `.gitignore`
- ✅ File contains API keys and should never be committed
- ✅ Each developer needs their own copy from Firebase Console
- ✅ Use `google-services.json.example` for reference only

### Troubleshooting

**File not found error:**
- Ensure `google-services.json` exists in `app/android/app/`
- Check file permissions

**Build errors:**
- Verify JSON structure matches the example
- Ensure package name matches: `io.airo.app` (or `com.airo.superapp` for legacy builds)
- Re-download from Firebase Console if corrupted

**Package Name Reference:**
- **Current (Production)**: `io.airo.app`
- **Legacy**: `com.airo.superapp`
- **AI Catalog Reference**: `com.android.ai.catalog` (for testing Gemini Nano features)

