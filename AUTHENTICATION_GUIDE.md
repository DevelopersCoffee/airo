# AIRO Assistant - Complete Authentication Guide

This guide provides a complete overview of the authentication system for AIRO Assistant across all platforms: Web (Chrome), Mobile (Flutter), and Desktop.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AIRO Assistant                            │
├─────────────────────────────────────────────────────────────┤
│  Web (Chrome)  │  Mobile (Android/iOS)  │  Desktop (Win/Mac) │
└────────┬────────────────┬──────────────────────┬─────────────┘
         │                │                      │
         ├─ OAuth2 Code Flow ─┐                  │
         │                    │                  │
         └────────────────────┼──────────────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Keycloak        │
                    │   (Auth Server)   │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │  Java Backend     │
                    │  (Spring Boot)    │
                    └───────────────────┘
```

## Quick Start

### 1. Start Keycloak

```bash
cd keycloak
docker-compose up -d
```

Access: `http://localhost:8080/admin` (admin/admin)

### 2. Configure Keycloak

Follow: [KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md)

Key steps:
- Create realm: `example`
- Create clients: `web`, `mobile`, `desktop`, `backend`
- Create test user: `testuser` / `password123`

### 3. Run Flutter App

```bash
# For mobile/desktop
flutter run

# For web (Chrome)
flutter run -d chrome
```

### 4. Run Backend (Optional)

```bash
# See BACKEND_AUTH_SETUP.md for full setup
mvn spring-boot:run
```

## Platform-Specific Setup

### Web (Chrome)

**File**: [WEB_AUTH_SETUP.md](WEB_AUTH_SETUP.md)

- Uses OAuth2 Authorization Code Flow
- Requires Node.js callback server
- Redirect URI: `http://localhost:3000/callback`
- Client ID: `web`

**Quick Start**:
```bash
npm install
node server.js
flutter run -d chrome
```

### Mobile (Android/iOS)

**File**: [KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md) - Mobile Client section

- Uses flutter_appauth package
- Handles OAuth2 flow natively
- Stores tokens securely
- Automatic token refresh

**Android**:
- Redirect URI: `com.example.teste://callback`
- Configured in `android/app/build.gradle.kts`

**iOS**:
- Redirect URI: `com.example.teste://callback`
- Configured in `ios/Runner/Info.plist`

### Desktop (Windows/Linux/macOS)

**File**: [KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md) - Desktop Client section

- Uses flutter_appauth package
- Local callback server on port 8888
- Redirect URI: `http://localhost:8888/callback`
- Client ID: `desktop`

## Authentication Flow

### 1. App Startup

```
App Start
    ↓
Check if authenticated (AuthProvider.initializeAuth)
    ↓
    ├─ Yes → Load user info → Show ChatScreen
    └─ No → Show LoginScreen
```

### 2. Login Process

```
User clicks "Sign in with Keycloak"
    ↓
Open Keycloak login page (platform-specific)
    ↓
User enters credentials
    ↓
Keycloak redirects to callback URL with auth code
    ↓
App exchanges code for tokens
    ↓
Store tokens securely
    ↓
Load user info
    ↓
Show ChatScreen
```

### 3. Token Refresh

```
Before each API call
    ↓
Check if token expired (5 min buffer)
    ↓
    ├─ Yes → Refresh token
    │   ├─ Success → Use new token
    │   └─ Fail → Logout user
    └─ No → Use existing token
```

## File Structure

```
lib/
├── main.dart                    # App entry point with auth routing
├── auth_service.dart            # Core authentication logic
├── providers/
│   └── auth_provider.dart       # State management for auth
├── screens/
│   ├── login_screen.dart        # Login UI
│   └── chat_screen.dart         # Main chat UI
├── services/
│   └── web_auth_service.dart    # Web-specific OAuth2 handler
└── models/
    └── user_entity.dart         # User data model

keycloak/
├── docker-compose.yaml          # Keycloak + PostgreSQL setup
└── .env                         # Environment variables

backend/                         # Java/Spring Boot (optional)
├── src/main/java/com/airo/
│   ├── config/
│   │   └── SecurityConfig.java
│   ├── controller/
│   │   └── AuthController.java
│   └── dto/
│       └── UserInfoResponse.java
└── application.yml
```

## Key Components

### AuthService (lib/auth_service.dart)

Core authentication logic:
- `authenticate()` - Initiate OAuth2 flow
- `isAuthenticated()` - Check auth status
- `getUserInfo()` - Fetch user details
- `logout()` - Clear tokens and logout
- `_refreshAccessToken()` - Refresh expired tokens

### AuthProvider (lib/providers/auth_provider.dart)

State management:
- Manages authentication state
- Provides user information
- Handles loading and error states
- Notifies UI of changes

### LoginScreen (lib/screens/login_screen.dart)

Login UI:
- Beautiful login interface
- Error message display
- Loading state handling
- Sign in button

### ChatScreen (lib/screens/chat_screen.dart)

Main app UI:
- Chat interface
- User info display
- Logout functionality
- Message handling

## Configuration

### Keycloak URLs

Update in `lib/auth_service.dart`:

```dart
static const String _keycloakUrl = 'http://localhost:8080';
static const String _realm = 'example';
```

### Redirect URIs

Platform-specific in `lib/auth_service.dart`:

```dart
static String _getRedirectUrl() {
  if (Platform.isAndroid) return 'com.example.teste://callback';
  if (Platform.isWeb) return 'http://localhost:3000/callback';
  if (Platform.isWindows) return 'http://localhost:8888/callback';
  // ...
}
```

### Backend Configuration

See [BACKEND_AUTH_SETUP.md](BACKEND_AUTH_SETUP.md)

## Testing

### Test Login

1. Run app: `flutter run`
2. Click "Sign in with Keycloak"
3. Enter: `testuser` / `password123`
4. Should see chat screen with user info

### Test Token Refresh

1. Login successfully
2. Wait for token to expire (or modify expiration in Keycloak)
3. App should automatically refresh token
4. Continue using app without re-login

### Test Logout

1. Click menu → Logout
2. Confirm logout
3. Should return to login screen

## Troubleshooting

### "Authentication failed"
- Check Keycloak is running: `docker-compose ps`
- Verify Keycloak URL in code
- Check client configuration in Keycloak

### "Invalid redirect URI"
- Ensure redirect URI matches exactly in Keycloak
- Check for trailing slashes
- Verify protocol (http vs https)

### "Token expired"
- Check token expiration settings in Keycloak
- Verify refresh token is stored
- Check network connectivity

### "CORS errors"
- Add your domain to Keycloak Web Origins
- Configure backend CORS settings
- Check browser console for details

## Security Best Practices

1. **Never commit secrets** - Use environment variables
2. **Use HTTPS in production** - Enable strict HTTPS in Keycloak
3. **Secure token storage** - Use flutter_secure_storage
4. **Token rotation** - Implement automatic refresh
5. **Validate tokens** - Check signature and expiration
6. **Rate limiting** - Prevent brute force attacks
7. **Logging** - Monitor authentication events

## Next Steps

1. ✅ Set up Keycloak
2. ✅ Configure clients
3. ✅ Test authentication
4. ⬜ Implement backend API
5. ⬜ Add role-based access control
6. ⬜ Set up production deployment
7. ⬜ Configure monitoring and logging

## Support

For issues or questions:
1. Check relevant setup guide (KEYCLOAK_SETUP.md, WEB_AUTH_SETUP.md, BACKEND_AUTH_SETUP.md)
2. Review troubleshooting section
3. Check Flutter/Keycloak documentation
4. Review logs in IDE console

## References

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Flutter AppAuth](https://pub.dev/packages/flutter_appauth)
- [OAuth2 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [Spring Security OAuth2](https://spring.io/projects/spring-security-oauth)

