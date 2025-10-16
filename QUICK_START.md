# AIRO Assistant - Quick Start Guide

Get authentication working in 5 minutes!

## Step 1: Start Keycloak (2 minutes)

```bash
cd keycloak
docker-compose up -d
```

Wait for Keycloak to start (check logs):
```bash
docker-compose logs -f keycloak
```

Access admin console: `http://localhost:8080/admin`
- Username: `admin`
- Password: `admin`

## Step 2: Configure Keycloak (2 minutes)

### Create Realm

1. Click "Master" dropdown → "Create Realm"
2. Name: `example`
3. Click "Create"

### Create Web Client

1. Clients → Create
2. Client ID: `web`
3. Client Protocol: `openid-connect`
4. Access Type: `public`
5. Save

**Configure**:
- Valid Redirect URIs: `http://localhost:3000/callback`
- Web Origins: `http://localhost:3000`
- Standard Flow Enabled: ON
- Implicit Flow Enabled: ON

### Create Mobile Client

1. Clients → Create
2. Client ID: `mobile`
3. Client Protocol: `openid-connect`
4. Access Type: `public`
5. Save

**Configure**:
- Valid Redirect URIs: `com.example.teste://callback`
- Standard Flow Enabled: ON
- Implicit Flow Enabled: ON

### Create Test User

1. Users → Add User
2. Username: `testuser`
3. Email: `testuser@example.com`
4. Save

**Set Password**:
1. Credentials tab
2. Password: `password123`
3. Temporary: OFF
4. Set Password

## Step 3: Update Flutter Dependencies (1 minute)

```bash
flutter pub get
```

This installs:
- `flutter_appauth` - OAuth2 handling
- `flutter_secure_storage` - Secure token storage
- `provider` - State management

## Step 4: Run the App (1 minute)

### For Mobile/Desktop

```bash
flutter run
```

### For Web (Chrome)

```bash
flutter run -d chrome
```

## Step 5: Test Authentication

1. App opens → Shows login screen
2. Click "Sign in with Keycloak"
3. Keycloak login page opens
4. Enter: `testuser` / `password123`
5. Redirected back to app
6. Chat screen appears with user info

## What's Implemented

✅ **Authentication Flow**
- Check auth status on app startup
- Route to login or chat screen
- Secure token storage

✅ **Login Screen**
- Beautiful UI
- Error handling
- Loading states

✅ **Chat Screen**
- User info display
- Logout functionality
- Message interface

✅ **Token Management**
- Automatic refresh (5 min before expiry)
- Secure storage
- Expiration checking

✅ **Multi-Platform Support**
- Web (Chrome) - OAuth2 Code Flow
- Mobile (Android/iOS) - flutter_appauth
- Desktop (Windows/Linux/macOS) - flutter_appauth

## File Structure

```
lib/
├── main.dart                    # Auth routing
├── auth_service.dart            # Core auth logic
├── providers/auth_provider.dart # State management
├── screens/
│   ├── login_screen.dart
│   └── chat_screen.dart
├── services/web_auth_service.dart
└── models/user_entity.dart
```

## Configuration

### Update Keycloak URL

Edit `lib/auth_service.dart`:

```dart
static const String _keycloakUrl = 'http://localhost:8080';
static const String _realm = 'example';
```

### Update App Package Name (Android)

Edit `android/app/build.gradle.kts`:

```kotlin
applicationId = "com.developerscoffee.airo"
manifestPlaceholders += [
    'appAuthRedirectScheme': 'com.developerscoffee.airo'
]
```

## Common Issues

### "Invalid redirect URI"
- Check Keycloak client configuration
- Ensure exact match (including trailing slashes)

### "Connection refused"
- Ensure Keycloak is running: `docker-compose ps`
- Check port 8080 is available

### "Authentication failed"
- Check username/password
- Verify user exists in Keycloak
- Check browser console for errors

### "Token expired"
- App automatically refreshes tokens
- If refresh fails, user is logged out
- Re-login to continue

## Next Steps

1. **Backend API** - See [BACKEND_AUTH_SETUP.md](BACKEND_AUTH_SETUP.md)
2. **Web Deployment** - See [WEB_AUTH_SETUP.md](WEB_AUTH_SETUP.md)
3. **Production Setup** - See [KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md)
4. **Full Guide** - See [AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md)

## Useful Commands

```bash
# View Keycloak logs
docker-compose logs -f keycloak

# Stop Keycloak
docker-compose down

# Restart Keycloak
docker-compose restart

# Clean Flutter build
flutter clean

# Get dependencies
flutter pub get

# Run tests
flutter test

# Build release
flutter build apk  # Android
flutter build ios  # iOS
flutter build web  # Web
```

## Testing Checklist

- [ ] Keycloak running
- [ ] Realm created
- [ ] Clients configured
- [ ] Test user created
- [ ] Flutter dependencies installed
- [ ] App runs without errors
- [ ] Login screen appears
- [ ] Can login with testuser
- [ ] Chat screen shows user info
- [ ] Can logout
- [ ] Can login again

## Support

For detailed information, see:
- [AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md) - Complete overview
- [KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md) - Keycloak configuration
- [WEB_AUTH_SETUP.md](WEB_AUTH_SETUP.md) - Web/Chrome setup
- [BACKEND_AUTH_SETUP.md](BACKEND_AUTH_SETUP.md) - Backend setup

## Architecture

```
User Opens App
    ↓
AuthWrapper checks authentication
    ↓
    ├─ Authenticated → ChatScreen
    └─ Not Authenticated → LoginScreen
                              ↓
                        User clicks login
                              ↓
                        Keycloak login page
                              ↓
                        User enters credentials
                              ↓
                        Tokens stored securely
                              ↓
                        User info loaded
                              ↓
                        ChatScreen displayed
```

## Security

- Tokens stored in secure storage (encrypted)
- Automatic token refresh before expiration
- HTTPS recommended for production
- No credentials stored locally
- Logout clears all tokens

Enjoy! 🚀

