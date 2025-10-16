# Authentication Debugging Guide

## Issue: "Authentication Failed" Without Username/Password Prompt

### Root Causes

1. **Keycloak Not Running**
   - Check: `docker ps | grep keycloak`
   - Fix: `cd keycloak && docker-compose up -d`

2. **Client Not Configured in Keycloak**
   - Check: Keycloak Admin Console → Realm → Clients
   - Fix: Create client with correct redirect URI

3. **Redirect URI Mismatch**
   - Android: Must be `com.example.teste://callback`
   - iOS: Must be `com.example.teste://callback`
   - Desktop: Must be `http://localhost:8888/callback`
   - Web: Must be `http://localhost:3000/callback`

4. **Client Secret Missing**
   - Check: Client → Credentials → Client Secret
   - Fix: Copy and verify in code

5. **Network/Firewall Issues**
   - Check: Can you access `http://localhost:8080` from device?
   - Fix: Ensure Keycloak is accessible from your device

---

## Step-by-Step Debugging

### Step 1: Verify Keycloak is Running

```bash
# Check if container is running
docker ps | grep keycloak

# If not running, start it
cd keycloak
docker-compose up -d

# Check logs
docker-compose logs keycloak
```

### Step 2: Access Keycloak Admin Console

1. Open browser: `http://localhost:8080/admin`
2. Login: `admin` / `admin`
3. Select realm: `example`

### Step 3: Verify Realm Configuration

1. Go to: Realm Settings
2. Check:
   - Realm name: `example`
   - Enabled: ON
   - User-Managed Access: OFF

### Step 4: Verify Client Configuration

1. Go to: Clients → `mobile` (for Android)
2. Check:
   - Enabled: ON
   - Client Authentication: OFF (for public clients)
   - Valid Redirect URIs: `com.example.teste://callback`
   - Valid Post Logout Redirect URIs: `com.example.teste://callback`
   - Web Origins: `*`

3. Go to: Clients → `web` (for Chrome)
2. Check:
   - Enabled: ON
   - Client Authentication: OFF
   - Valid Redirect URIs: `http://localhost:3000/callback`
   - Valid Post Logout Redirect URIs: `http://localhost:3000/callback`
   - Web Origins: `http://localhost:3000`

### Step 5: Verify Test User

1. Go to: Users → `testuser`
2. Check:
   - Enabled: ON
   - Email Verified: ON
3. Go to: Credentials
4. Set password: `password123`
5. Temporary: OFF

### Step 6: Check App Logs

Run with verbose logging:

```bash
# Android/Desktop
flutter run -v

# Chrome
flutter run -d chrome -v
```

Look for:
- `Starting authentication with clientId:`
- `Auth config:`
- `Authentication successful` or error message

### Step 7: Test Keycloak Directly

```bash
# Get token directly from Keycloak
curl -X POST http://localhost:8080/realms/example/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=mobile" \
  -d "username=testuser" \
  -d "password=password123" \
  -d "grant_type=password"
```

If this works, Keycloak is fine. If not, check Keycloak logs.

---

## Common Error Messages

### "Authentication cancelled"
- **Cause**: User cancelled the login flow
- **Fix**: Try again, ensure Keycloak login page appears

### "No access token received"
- **Cause**: Keycloak didn't return token
- **Fix**: Check client configuration, verify user credentials

### "Connection refused"
- **Cause**: Can't reach Keycloak
- **Fix**: Check Keycloak is running, check network connectivity

### "Invalid redirect URI"
- **Cause**: Redirect URI doesn't match Keycloak config
- **Fix**: Update Keycloak client redirect URI to match app

### "Client not found"
- **Cause**: Client doesn't exist in Keycloak
- **Fix**: Create client in Keycloak admin console

---

## Platform-Specific Issues

### Android

**Issue**: "Redirect URI not registered"
- **Fix**: Update `android/app/build.gradle.kts`:
```kotlin
manifestPlaceholders += [
    'appAuthRedirectScheme': 'com.example.teste'
]
```

**Issue**: "Network error"
- **Fix**: Ensure emulator can reach `http://10.0.2.2:8080` (use 10.0.2.2 instead of localhost)

### Chrome

**Issue**: "Web authentication not yet implemented"
- **Fix**: Use Android/Desktop for now, or implement web auth handler

### Desktop (Windows/Linux/macOS)

**Issue**: "Port 8888 already in use"
- **Fix**: Change redirect URL port in auth_service.dart

---

## Keycloak Configuration Checklist

- [ ] Keycloak running: `docker ps | grep keycloak`
- [ ] Realm created: `example`
- [ ] Client created: `mobile` (for Android)
- [ ] Client created: `web` (for Chrome)
- [ ] Client created: `desktop` (for Desktop)
- [ ] Redirect URIs configured correctly
- [ ] Test user created: `testuser`
- [ ] Test user password set: `password123`
- [ ] Test user enabled
- [ ] Email verified for test user

---

## Quick Fix Checklist

If authentication is failing:

1. [ ] Run: `docker ps | grep keycloak`
2. [ ] If not running: `cd keycloak && docker-compose up -d`
3. [ ] Access: `http://localhost:8080/admin`
4. [ ] Login: `admin` / `admin`
5. [ ] Select realm: `example`
6. [ ] Go to Clients
7. [ ] Select `mobile` (for Android)
8. [ ] Check: Enabled = ON
9. [ ] Check: Valid Redirect URIs = `com.example.teste://callback`
10. [ ] Go to Users
11. [ ] Select `testuser`
12. [ ] Check: Enabled = ON
13. [ ] Go to Credentials
14. [ ] Set password: `password123`
15. [ ] Temporary: OFF
16. [ ] Run app: `flutter run -v`
17. [ ] Click "Sign in with Keycloak"
18. [ ] Check logs for errors

---

## Advanced Debugging

### Enable Keycloak Debug Logging

Add to `keycloak/docker-compose.yaml`:

```yaml
environment:
  KC_LOG_LEVEL: debug
  KC_LOG: console
```

Then restart: `docker-compose restart keycloak`

### Check Keycloak Logs

```bash
docker-compose logs -f keycloak
```

### Test with curl

```bash
# Test token endpoint
curl -v http://localhost:8080/realms/example/protocol/openid-connect/token

# Test userinfo endpoint
curl -v http://localhost:8080/realms/example/protocol/openid-connect/userinfo
```

### Check Network Connectivity

```bash
# From Android emulator
adb shell ping 10.0.2.2

# From desktop
ping localhost
```

---

## Still Not Working?

1. Check all items in "Keycloak Configuration Checklist"
2. Review logs: `flutter run -v`
3. Check Keycloak logs: `docker-compose logs keycloak`
4. Verify network connectivity
5. Try on different platform (Android vs Desktop vs Chrome)
6. Clear app data and try again
7. Restart Keycloak: `docker-compose restart keycloak`

---

## Support

For more help:
- See: AUTHENTICATION_GUIDE.md
- See: KEYCLOAK_SETUP.md
- Check: TROUBLESHOOTING.md

