# 🔐 URGENT: Set Up GitHub Secret to Fix Build

## The build is failing because the `GOOGLE_SERVICES_JSON` secret is missing.

---

## ⚡ Quick Fix (5 minutes)

### Step 1: Encode the File

**Open PowerShell** and run this command:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app\android\app\google-services.json")) | Set-Clipboard
```

This will copy the encoded string to your clipboard.

**Alternative (if above doesn't work)**:

```powershell
$bytes = [System.IO.File]::ReadAllBytes("app\android\app\google-services.json")
$base64 = [System.Convert]::ToBase64String($bytes)
$base64 | Set-Clipboard
Write-Host "Copied to clipboard!"
```

---

### Step 2: Add to GitHub

1. **Go to**: https://github.com/DevelopersCoffee/airo/settings/secrets/actions

2. **Click**: "New repository secret" (green button)

3. **Enter**:
   - **Name**: `GOOGLE_SERVICES_JSON`
   - **Value**: Press `Ctrl+V` to paste from clipboard

4. **Click**: "Add secret" (green button)

---

### Step 3: Re-run the Failed Build

1. **Go to**: https://github.com/DevelopersCoffee/airo/actions

2. **Click** on the failed workflow run (the one with the red X)

3. **Click**: "Re-run all jobs" button (top right)

4. **Wait** ~15-20 minutes for the build to complete

---

## ✅ That's It!

Once you add the secret and re-run the build, it should succeed!

---

## 🔍 Troubleshooting

### If the PowerShell command doesn't work:

**Option 1: Use Python**
```python
import base64
with open('app/android/app/google-services.json', 'rb') as f:
    encoded = base64.b64encode(f.read()).decode()
    print(encoded)
```

**Option 2: Use Online Tool**
1. Go to: https://www.base64encode.org/
2. Upload `app/android/app/google-services.json`
3. Click "Encode"
4. Copy the result

**Option 3: Manual Copy**
1. Open `app/android/app/google-services.json` in a text editor
2. Copy the entire contents
3. Go to: https://www.base64encode.org/
4. Paste the contents
5. Click "Encode"
6. Copy the result

---

## 📋 Verification

After adding the secret:

1. ✅ Secret name is exactly: `GOOGLE_SERVICES_JSON` (all caps, no spaces)
2. ✅ Secret value is the base64-encoded string (very long, starts with something like `ewogICJ...`)
3. ✅ You clicked "Add secret"
4. ✅ You re-ran the failed workflow

---

## 🎯 Expected Result

After re-running the workflow with the secret added:

- ✅ Android build succeeds
- ✅ APK is created
- ✅ Release is published
- ✅ Download link works

---

## 📞 Need Help?

If you're still stuck, check:
- GitHub Actions logs for specific error messages
- Make sure the secret name is exactly `GOOGLE_SERVICES_JSON`
- Make sure you re-ran the workflow after adding the secret

---

**Quick Links**:
- Add Secret: https://github.com/DevelopersCoffee/airo/settings/secrets/actions
- View Actions: https://github.com/DevelopersCoffee/airo/actions
- View Releases: https://github.com/DevelopersCoffee/airo/releases

