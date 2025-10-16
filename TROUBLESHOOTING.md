# AIRO Assistant - Troubleshooting Guide

## Common Issues and Solutions

### Keycloak Issues

#### 1. "Connection refused" or "Cannot connect to Keycloak"

**Symptoms**:
- App shows "Failed to initialize authentication"
- Login button doesn't work
- Network error in logs

**Solutions**:
```bash
# Check if Keycloak is running
docker-compose ps

# View logs
docker-compose logs keycloak

# Restart Keycloak
docker-compose restart keycloak

# Check if port 8080 is available
netstat -an | grep 8080  # Linux/Mac
netstat -ano | findstr :8080  # Windows

# If port is in use, stop the process or change port in docker-compose.yaml
```

**Verify**:
- Open `http://localhost:8080` in browser
- Should see Keycloak login page
- Access admin console: `http://localhost:8080/admin`

#### 2. "Invalid redirect URI"

**Symptoms**:
- After login, error: "Invalid redirect URI"
- Redirected back to Keycloak login

**Causes**:
- Redirect URI in Keycloak doesn't match app configuration
- Trailing slash mismatch
- Protocol mismatch (http vs https)

**Solutions**:

1. **Check Keycloak Configuration**:
   - Go to Clients → Select client (web/mobile/desktop)
   - Check "Valid Redirect URIs"
   - Ensure exact match with app configuration

2. **Check App Configuration**:
   - For mobile: `lib/auth_service.dart` line 18
   - For web: `lib/services/web_auth_service.dart` line 12
   - For desktop: `lib/auth_service.dart` line 18

3. **Common Mismatches**:
   ```
   ❌ http://localhost:3000/callback vs http://localhost:3000/callback/
   ❌ http://localhost:3000 vs https://localhost:3000
   ❌ com.example.teste://callback vs com.example.teste://callback/
   ```

**Fix**:
- Update Keycloak to match app exactly
- Or update app to match Keycloak

#### 3. "Realm not found"

**Symptoms**:
- Error: "Realm 'example' not found"
- 404 errors in logs

**Solutions**:
```bash
# Check if realm exists
# Go to Keycloak Admin Console
# Look for realm dropdown (top left)

# If realm doesn't exist:
# 1. Click "Master" dropdown
# 2. Click "Create Realm"
# 3. Name: "example"
# 4. Click "Create"
```

#### 4. "Client not found"

**Symptoms**:
- Error: "Client 'web' not found"
- Authentication fails

**Solutions**:
```bash
# Check if client exists
# Go to Keycloak Admin Console
# Select realm "example"
# Go to Clients
# Look for client (web/mobile/desktop)

# If client doesn't exist:
# 1. Click "Create"
# 2. Client ID: "web" (or mobile/desktop)
# 3. Client Protocol: "openid-connect"
# 4. Access Type: "public"
# 5. Click "Save"
```

### Authentication Issues

#### 5. "Authentication failed - no access token received"

**Symptoms**:
- Login button clicked but nothing happens
- Error in logs: "no access token received"

**Causes**:
- Client not configured correctly
- Scopes not available
- User doesn't have permission

**Solutions**:
1. Check client configuration in Keycloak:
   - Standard Flow Enabled: ON
   - Implicit Flow Enabled: ON
   - Direct Access Grants Enabled: ON

2. Check scopes:
   - Go to Client Scopes
   - Ensure: openid, profile, email exist

3. Check user:
   - User exists in Keycloak
   - User has correct roles

#### 6. "Token expired or invalid"

**Symptoms**:
- Works initially, then fails after a while
- Error: "Token expired or invalid"

**Causes**:
- Token actually expired
- Token refresh failed
- Network issue during refresh

**Solutions**:
```bash
# Check token expiration settings in Keycloak
# Go to Realm Settings → Tokens
# Check "Access Token Lifespan" (default: 5 minutes)

# For testing, set to longer duration:
# Access Token Lifespan: 30 minutes
# Refresh Token Lifespan: 60 minutes
```

**In Code**:
- App automatically refreshes 5 minutes before expiry
- If refresh fails, user is logged out
- Check network connectivity

#### 7. "No refresh token available"

**Symptoms**:
- Token expires and user is logged out
- Should have been refreshed automatically

**Causes**:
- Refresh token not stored
- Refresh token expired
- Keycloak not configured for refresh

**Solutions**:
1. Check Keycloak client configuration:
   - Go to Clients → Select client
   - Check "Standard Flow Enabled": ON
   - Check "Implicit Flow Enabled": ON

2. Check token storage:
   - Ensure `flutter_secure_storage` is working
   - Check device storage permissions

3. Increase refresh token lifespan:
   - Realm Settings → Tokens
   - Refresh Token Lifespan: 60 minutes

### Flutter/App Issues

#### 8. "flutter_appauth not found"

**Symptoms**:
- Error: "Target of URI doesn't exist: 'package:flutter_appauth'"
- Build fails

**Solutions**:
```bash
# Install dependencies
flutter pub get

# Clean and rebuild
flutter clean
flutter pub get
flutter run
```

#### 9. "flutter_secure_storage not working"

**Symptoms**:
- Tokens not persisted
- Login works but logout/restart loses session

**Solutions**:

**Android**:
```bash
# Check AndroidManifest.xml has permissions
# android/app/src/main/AndroidManifest.xml

# Should have:
# <uses-permission android:name="android.permission.USE_CREDENTIALS" />
```

**iOS**:
```bash
# Check Keychain sharing enabled
# ios/Runner/Runner.entitlements

# Should have:
# <key>keychain-access-groups</key>
# <array>
#   <string>$(AppIdentifierPrefix)com.example.teste</string>
# </array>
```

**Windows/Linux/macOS**:
- Check file permissions
- Ensure app can write to storage directory

#### 10. "CORS errors in web"

**Symptoms**:
- Browser console shows CORS errors
- API calls fail from web app

**Solutions**:

1. **Add to Keycloak Web Origins**:
   - Go to Clients → web
   - Web Origins: `http://localhost:3000`

2. **Configure Backend CORS**:
   - See BACKEND_AUTH_SETUP.md
   - Add allowed origins

3. **Check Browser Console**:
   - Open DevTools (F12)
   - Check Console tab for CORS errors
   - Note the exact error message

#### 11. "App crashes on startup"

**Symptoms**:
- App starts then immediately crashes
- No error message visible

**Solutions**:
```bash
# Check logs
flutter run -v

# Look for:
# - Null pointer exceptions
# - Missing dependencies
# - Permission errors

# Common causes:
# 1. Missing flutter_secure_storage initialization
# 2. Missing provider setup
# 3. Null safety issues
```

### Web-Specific Issues

#### 12. "Callback not received"

**Symptoms**:
- Login page opens but doesn't redirect back
- Stuck on Keycloak login page

**Solutions**:
1. Check redirect URI in Keycloak:
   - Should be: `http://localhost:3000/callback`

2. Check callback server running:
   ```bash
   # If using Node.js server
   node server.js
   # Should see: "Server running on http://localhost:3000"
   ```

3. Check browser console:
   - Open DevTools (F12)
   - Check Console and Network tabs
   - Look for redirect attempts

#### 13. "localStorage not working"

**Symptoms**:
- Tokens not saved
- Logout/refresh loses session

**Solutions**:
1. Check browser privacy mode:
   - localStorage disabled in private/incognito mode
   - Use normal browsing mode

2. Check browser storage:
   - DevTools → Application → Local Storage
   - Should see `oauth_code` and `oauth_state`

3. Check browser permissions:
   - Some browsers restrict storage
   - Check browser settings

### Backend Issues

#### 14. "401 Unauthorized from backend"

**Symptoms**:
- Login works but API calls fail with 401
- Error: "Unauthorized"

**Causes**:
- Token not sent in request
- Token format incorrect
- Backend not configured for OAuth2

**Solutions**:
1. Check token is sent:
   ```dart
   // Should include Authorization header
   headers: {
     'Authorization': 'Bearer $token',
   }
   ```

2. Check token format:
   - Should be: `Bearer <token>`
   - Not: `Token <token>` or just `<token>`

3. Check backend configuration:
   - See BACKEND_AUTH_SETUP.md
   - Verify JWT issuer URI
   - Verify JWK set URI

#### 15. "Invalid token signature"

**Symptoms**:
- Backend rejects token
- Error: "Invalid token signature"

**Causes**:
- Backend using wrong key to verify
- Token from different Keycloak instance
- Keycloak keys rotated

**Solutions**:
1. Check issuer URI in backend:
   ```yaml
   spring:
     security:
       oauth2:
         resourceserver:
           jwt:
             issuer-uri: http://localhost:8080/realms/example
   ```

2. Verify JWK set is accessible:
   ```bash
   curl http://localhost:8080/realms/example/protocol/openid-connect/certs
   ```

3. Restart backend to refresh keys:
   ```bash
   mvn spring-boot:run
   ```

## Debugging Tips

### 1. Enable Verbose Logging

```bash
# Flutter
flutter run -v

# Keycloak
docker-compose logs -f keycloak
```

### 2. Check Network Requests

**Browser DevTools**:
- F12 → Network tab
- Look for requests to Keycloak
- Check response status and body

**Dart DevTools**:
- Run: `flutter pub global activate devtools`
- Run: `devtools`
- Check HTTP requests

### 3. Inspect Tokens

```dart
// Decode token to see claims
import 'dart:convert';

String token = "your_token_here";
List<String> parts = token.split('.');
String payload = parts[1];
String normalized = base64Url.normalize(payload);
String decoded = utf8.decode(base64Url.decode(normalized));
Map<String, dynamic> claims = json.decode(decoded);
print(claims);
```

### 4. Test Keycloak Directly

```bash
# Get token
curl -X POST http://localhost:8080/realms/example/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=web" \
  -d "username=testuser" \
  -d "password=password123"

# Get user info
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/realms/example/protocol/openid-connect/userinfo
```

## Getting Help

1. **Check Documentation**:
   - QUICK_START.md - Quick setup
   - AUTHENTICATION_GUIDE.md - Complete guide
   - KEYCLOAK_SETUP.md - Keycloak config

2. **Check Logs**:
   - Flutter: `flutter run -v`
   - Keycloak: `docker-compose logs keycloak`
   - Browser: DevTools Console

3. **Check Configuration**:
   - Keycloak clients and realms
   - App redirect URIs
   - Backend OAuth2 settings

4. **Test Manually**:
   - Use curl to test Keycloak
   - Use Postman to test backend
   - Use browser DevTools to debug web

5. **Reset Everything**:
   ```bash
   # Stop Keycloak
   docker-compose down
   
   # Clean Flutter
   flutter clean
   
   # Start fresh
   docker-compose up -d
   flutter pub get
   flutter run
   ```

## Still Having Issues?

1. Review the relevant setup guide
2. Check all configuration matches
3. Enable verbose logging
4. Test each component separately
5. Check browser/IDE console for errors
6. Verify network connectivity
7. Try on different platform (web/mobile/desktop)

