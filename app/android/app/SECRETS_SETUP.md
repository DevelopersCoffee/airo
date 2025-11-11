# Secrets Setup Guide

## Google Services Configuration

### Setup Instructions

1. **Get your Firebase configuration:**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select your project: `devscoffee-airo`
   - Navigate to Project Settings > General
   - Under "Your apps", find the Android app
   - Download `google-services.json`

2. **Place the file:**
   ```bash
   cp /path/to/downloaded/google-services.json app/android/app/google-services.json
   ```

3. **Verify the file structure:**
   - Use `google-services.json.example` as a reference
   - Ensure all required fields are present
   - Never commit the actual `google-services.json` file

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
- Ensure package name matches: `com.android.ai.catalog`
- Re-download from Firebase Console if corrupted

