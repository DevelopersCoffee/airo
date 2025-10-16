# Quick Test Guide - AIRO Assistant

## 🚀 Get Started in 5 Minutes

### Prerequisites

- Flutter installed
- Keycloak running: `cd keycloak && docker-compose up -d`
- Android emulator or Chrome browser

---

## Step 1: Install Dependencies (2 min)

```bash
cd c:\Users\chauh\develop\airo
flutter pub get
```

**Expected Output:**
```
Running "flutter pub get" in airo...
...
Got dependencies!
```

---

## Step 2: Start Keycloak (1 min)

```bash
cd keycloak
docker-compose up -d
```

**Verify:**
```bash
docker ps | grep keycloak
```

Should show keycloak container running.

---

## Step 3: Configure Keycloak (1 min)

1. Open: `http://localhost:8080/admin`
2. Login: `admin` / `admin`
3. Select realm: `example`
4. Go to: Clients → `mobile`
5. Verify: Valid Redirect URIs = `com.example.teste://callback`
6. Go to: Users → `testuser`
7. Verify: Password = `password123`

---

## Step 4: Run on Chrome (1 min)

```bash
flutter run -d chrome
```

**Expected Output:**
```
Launching lib\main.dart on Chrome in debug mode...
...
Application finished.
```

**In Browser:**
1. See login screen
2. Click "Sign in with Keycloak"
3. Enter: `testuser` / `password123`
4. See chat screen

---

## Step 5: Test Features (5 min)

### Test Chat

1. Type: "What is protein?"
2. Click send button
3. See AI response
4. Message saved to database

### Test Food Capture (Android only)

1. Click menu → "Capture Food"
2. Take photo
3. App extracts text
4. Food item saved

### Test Gallery (Android only)

1. Click menu → "Select from Gallery"
2. Choose image
3. App processes image
4. Food item saved

---

## 🧪 Testing Checklist

### Authentication
- [ ] Login with testuser/password123
- [ ] See chat screen after login
- [ ] User info displayed
- [ ] Logout works

### Chat
- [ ] Send message
- [ ] Receive AI response
- [ ] Messages appear in chat
- [ ] Message history persists

### Database
- [ ] Food items saved
- [ ] Messages saved
- [ ] Data persists after restart
- [ ] Offline access works

### UI/UX
- [ ] Chat interface responsive
- [ ] Messages scroll smoothly
- [ ] Input field works
- [ ] Menu options visible

---

## 🐛 Common Issues

### "Authentication failed"

**Fix:**
1. Check Keycloak running: `docker ps | grep keycloak`
2. Check client configured: `http://localhost:8080/admin`
3. Check test user exists
4. Check redirect URI matches

### "Connection refused"

**Fix:**
1. Start Keycloak: `cd keycloak && docker-compose up -d`
2. Wait 10 seconds for startup
3. Try again

### "No access token received"

**Fix:**
1. Check Keycloak logs: `docker-compose logs keycloak`
2. Verify client is enabled
3. Check scopes: openid, profile, email

### "Database error"

**Fix:**
1. Clear app data
2. Restart app
3. Check logs: `flutter run -v`

---

## 📊 Test Results

### Chrome Testing

| Feature | Status | Notes |
|---------|--------|-------|
| Login | ✅ | Works with Keycloak |
| Chat | ✅ | Local AI responses |
| Database | ✅ | SQLite working |
| UI | ✅ | Responsive design |

### Android Testing

| Feature | Status | Notes |
|---------|--------|-------|
| Login | ✅ | Works with Keycloak |
| Chat | ✅ | Gemini Nano if available |
| Camera | ✅ | OCR working |
| Gallery | ✅ | Image selection working |
| Database | ✅ | SQLite working |
| UI | ✅ | Touch optimized |

---

## 🎯 Next Steps

### If All Tests Pass

1. ✅ Commit code
2. ✅ Document findings
3. ✅ Start Phase 2 (Notifications & Reminders)

### If Tests Fail

1. Check TROUBLESHOOTING.md
2. Review AUTH_DEBUGGING_GUIDE.md
3. Check logs: `flutter run -v`
4. Try on different platform

---

## 📱 Platform-Specific Commands

### Chrome

```bash
flutter run -d chrome
```

### Android Emulator

```bash
# Start emulator
emulator -avd Pixel_9_API_35

# Run app
flutter run
```

### Android Device

```bash
# Connect device via USB
adb devices

# Run app
flutter run
```

### Windows Desktop

```bash
flutter run -d windows
```

### Linux Desktop

```bash
flutter run -d linux
```

### macOS Desktop

```bash
flutter run -d macos
```

---

## 🔍 Debugging

### View Logs

```bash
flutter run -v
```

### Check Database

```bash
# On Android
adb shell
sqlite3 /data/data/com.example.teste/databases/airo_assistant.db
.tables
SELECT * FROM food_items;
```

### Check Keycloak

```bash
docker-compose logs -f keycloak
```

### Check Network

```bash
# From Android emulator
adb shell ping 10.0.2.2

# From desktop
ping localhost
```

---

## ✨ Success Indicators

You'll know everything is working when:

1. ✅ Login screen appears
2. ✅ Can login with testuser/password123
3. ✅ Chat screen appears
4. ✅ Can send messages
5. ✅ Receive AI responses
6. ✅ Messages persist
7. ✅ No errors in logs
8. ✅ App runs smoothly

---

## 📞 Support

- **Auth Issues**: See AUTH_DEBUGGING_GUIDE.md
- **Database Issues**: See TROUBLESHOOTING.md
- **General Help**: See AIRO_BUILDING_BLOCKS_ROADMAP.md
- **Implementation**: See EPICS_APP1_APP2_APP3_IMPLEMENTATION.md

---

## 🎉 Ready to Test!

```bash
# Install dependencies
flutter pub get

# Start Keycloak
cd keycloak && docker-compose up -d

# Run on Chrome
flutter run -d chrome

# Or run on Android
flutter run
```

**Estimated Time**: 5 minutes to full working system!

---

**Questions?** Check the documentation files or review the logs with `flutter run -v`

