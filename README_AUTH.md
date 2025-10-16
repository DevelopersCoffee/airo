# AIRO Assistant - Authentication System

Complete, production-ready authentication system for web, mobile, and desktop applications using Keycloak and OAuth2.

## 🚀 Quick Start (5 Minutes)

```bash
# 1. Start Keycloak
cd keycloak && docker-compose up -d

# 2. Configure Keycloak (see QUICK_START.md)
# - Create realm: example
# - Create clients: web, mobile, desktop
# - Create test user: testuser / password123

# 3. Install dependencies
flutter pub get

# 4. Run app
flutter run              # Mobile/Desktop
flutter run -d chrome    # Web
```

**Login with**: `testuser` / `password123`

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[QUICK_START.md](QUICK_START.md)** | 5-minute setup guide |
| **[AUTHENTICATION_GUIDE.md](AUTHENTICATION_GUIDE.md)** | Complete overview |
| **[KEYCLOAK_SETUP.md](KEYCLOAK_SETUP.md)** | Keycloak configuration |
| **[WEB_AUTH_SETUP.md](WEB_AUTH_SETUP.md)** | Web/Chrome setup |
| **[BACKEND_AUTH_SETUP.md](BACKEND_AUTH_SETUP.md)** | Java/Spring Boot backend |
| **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** | What was implemented |
| **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** | Common issues & fixes |

## ✨ Features

### ✅ Implemented

- [x] OAuth2 Authorization Code Flow
- [x] Multi-platform support (Web, Mobile, Desktop)
- [x] Secure token storage (encrypted)
- [x] Automatic token refresh (5 min buffer)
- [x] User information retrieval
- [x] Logout functionality
- [x] Error handling & recovery
- [x] Beautiful login UI
- [x] State management with Provider
- [x] Comprehensive documentation

### 🔄 Ready for Implementation

- [ ] Backend API integration
- [ ] Role-based access control
- [ ] User profile screen
- [ ] Production deployment
- [ ] Monitoring & logging

## 🏗️ Architecture

```
┌─────────────────────────────────────────┐
│         AIRO Assistant App              │
│  (Web, Mobile, Desktop)                 │
└────────────────┬────────────────────────┘
                 │
         ┌───────▼────────┐
         │  AuthWrapper   │
         │  (Routing)     │
         └───────┬────────┘
                 │
    ┌────────────┴────────────┐
    │                         │
┌───▼────┐            ┌──────▼──┐
│ Login  │            │  Chat   │
│Screen  │            │ Screen  │
└───┬────┘            └─────────┘
    │
    └─────────────────┬──────────────┐
                      │              │
            ┌─────────▼────┐  ┌──────▼──────┐
            │ AuthProvider │  │ AuthService │
            │ (State Mgmt) │  │ (Core Logic)│
            └──────────────┘  └──────┬──────┘
                                     │
                    ┌────────────────┴────────────────┐
                    │                                 │
            ┌───────▼──────┐              ┌──────────▼────┐
            │flutter_appauth│              │WebAuthService │
            │(Mobile/Desktop)│             │(Web/Chrome)   │
            └───────┬──────┘              └──────────┬────┘
                    │                                 │
                    └────────────────┬────────────────┘
                                     │
                            ┌────────▼────────┐
                            │   Keycloak      │
                            │ (Auth Server)   │
                            │ localhost:8080  │
                            └─────────────────┘
```

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry + AuthWrapper
├── auth_service.dart                  # Core authentication
├── providers/
│   └── auth_provider.dart             # State management
├── screens/
│   ├── login_screen.dart              # Login UI
│   └── chat_screen.dart               # Chat UI
├── services/
│   └── web_auth_service.dart          # Web OAuth2
└── models/
    └── user_entity.dart               # User model

keycloak/
├── docker-compose.yaml                # Keycloak + PostgreSQL
└── .env                               # Environment variables
```

## 🔐 Security Features

- **Encrypted Token Storage**: Uses `flutter_secure_storage`
- **Automatic Token Refresh**: 5 minutes before expiration
- **Secure Logout**: Clears all tokens and ends session
- **HTTPS Ready**: Configured for production HTTPS
- **CORS Protection**: Configured for allowed origins
- **Token Validation**: Signature and expiration checks

## 🌐 Platform Support

| Platform | Status | Flow | Storage |
|----------|--------|------|---------|
| **Web (Chrome)** | ✅ Ready | OAuth2 Code | localStorage |
| **Android** | ✅ Ready | flutter_appauth | Encrypted |
| **iOS** | ✅ Ready | flutter_appauth | Keychain |
| **Windows** | ✅ Ready | flutter_appauth | Encrypted |
| **Linux** | ✅ Ready | flutter_appauth | Encrypted |
| **macOS** | ✅ Ready | flutter_appauth | Keychain |

## 🔧 Configuration

### Keycloak URL

Edit `lib/auth_service.dart`:
```dart
static const String _keycloakUrl = 'http://localhost:8080';
static const String _realm = 'example';
```

### Redirect URIs

Automatically detected by platform:
- **Web**: `http://localhost:3000/callback`
- **Mobile**: `com.example.teste://callback`
- **Desktop**: `http://localhost:8888/callback`

### Token Expiration

Edit in Keycloak Realm Settings → Tokens:
- Access Token Lifespan: 5 minutes (default)
- Refresh Token Lifespan: 30 minutes (default)

## 📦 Dependencies

```yaml
flutter_appauth: ^7.0.0          # OAuth2 handling
flutter_secure_storage: ^9.2.2   # Secure storage
provider: ^6.1.2                 # State management
http: ^1.2.1                     # HTTP client
```

## 🧪 Testing

### Test Checklist

- [ ] Keycloak running (`docker-compose ps`)
- [ ] Realm created: `example`
- [ ] Clients created: `web`, `mobile`, `desktop`
- [ ] Test user created: `testuser`
- [ ] Dependencies installed: `flutter pub get`
- [ ] App runs: `flutter run`
- [ ] Login works
- [ ] Chat screen displays
- [ ] Logout works
- [ ] Can login again

### Manual Testing

```bash
# Test Keycloak directly
curl -X POST http://localhost:8080/realms/example/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password&client_id=web&username=testuser&password=password123"

# Get user info
curl -H "Authorization: Bearer <token>" \
  http://localhost:8080/realms/example/protocol/openid-connect/userinfo
```

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Connection refused" | Check Keycloak: `docker-compose ps` |
| "Invalid redirect URI" | Verify exact match in Keycloak client |
| "Token expired" | App auto-refreshes, check network |
| "CORS errors" | Add origin to Keycloak Web Origins |
| "Authentication failed" | Check credentials and user exists |

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions.

## 🚀 Next Steps

### Week 1
1. ✅ Set up Keycloak
2. ✅ Test authentication
3. ✅ Test on all platforms

### Week 2
1. Implement backend API (see [BACKEND_AUTH_SETUP.md](BACKEND_AUTH_SETUP.md))
2. Add chat functionality
3. Implement role-based access

### Week 3+
1. Production deployment
2. Monitoring & logging
3. Performance optimization

## 📖 API Reference

### AuthService

```dart
// Authenticate user
Future<bool> authenticate()

// Check if authenticated
Future<bool> isAuthenticated()

// Get user information
Future<UserEntity> getUserInfo()

// Logout user
Future<bool> logout()

// Get access token
Future<String?> getAccessToken()

// Check if needs authentication
Future<bool> needsAuthentication()

// Get token validity duration
Future<Duration?> getTokenValidityDuration()
```

### AuthProvider

```dart
// Initialize authentication
Future<void> initializeAuth()

// Authenticate user
Future<bool> authenticate()

// Logout user
Future<bool> logout()

// Refresh user info
Future<void> refreshUserInfo()

// Clear error message
void clearError()

// Getters
bool get isAuthenticated
bool get isLoading
String? get error
UserEntity? get user
```

## 🔗 Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [Flutter AppAuth](https://pub.dev/packages/flutter_appauth)
- [OAuth2 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [Spring Security OAuth2](https://spring.io/projects/spring-security-oauth)

## 📝 License

This authentication system is part of the AIRO Assistant project.

## 🤝 Support

For issues or questions:
1. Check relevant documentation
2. Review [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
3. Check Flutter/Keycloak documentation
4. Review logs with `flutter run -v`

---

**Ready to build?** Start with [QUICK_START.md](QUICK_START.md) 🚀

