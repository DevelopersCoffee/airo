# AIRO Assistant - Architecture Diagrams

## 1. Application Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    App Startup                              │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  AuthWrapper.initState │
            │  Calls initializeAuth()│
            └────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │ AuthService.isAuth()   │
            │ Check token & expiry   │
            └────────────┬───────────┘
                         │
            ┌────────────┴────────────┐
            │                         │
        ┌───▼────┐              ┌────▼────┐
        │ Token  │              │ No      │
        │ Valid? │              │ Token   │
        └───┬────┘              └────┬────┘
            │                        │
        ┌───▼────┐              ┌────▼────┐
        │ YES    │              │ NO      │
        └───┬────┘              └────┬────┘
            │                        │
        ┌───▼──────────┐        ┌────▼──────────┐
        │ Load User    │        │ Show Login    │
        │ Info         │        │ Screen        │
        └───┬──────────┘        └────┬──────────┘
            │                        │
        ┌───▼──────────┐        ┌────▼──────────┐
        │ Show Chat    │        │ User Clicks   │
        │ Screen       │        │ Sign In       │
        └──────────────┘        └────┬──────────┘
                                     │
                            ┌────────▼────────┐
                            │ Open Keycloak   │
                            │ Login Page      │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ User Enters     │
                            │ Credentials     │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Keycloak        │
                            │ Validates &     │
                            │ Redirects       │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ App Receives    │
                            │ Auth Code       │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Exchange Code   │
                            │ for Tokens      │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Store Tokens    │
                            │ Securely        │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Load User Info  │
                            └────────┬────────┘
                                     │
                            ┌────────▼────────┐
                            │ Show Chat       │
                            │ Screen          │
                            └─────────────────┘
```

## 2. Token Lifecycle

```
┌──────────────────────────────────────────────────────────────┐
│                    Token Lifecycle                           │
└──────────────────────────────────────────────────────────────┘

Login
  │
  ├─ Access Token (5 min)
  │  └─ Used for API calls
  │
  ├─ Refresh Token (30 min)
  │  └─ Used to get new access token
  │
  └─ ID Token
     └─ Contains user info

                    ▼ (Time passes)

Before API Call
  │
  ├─ Check if token expired?
  │  │
  │  ├─ NO → Use existing token
  │  │
  │  └─ YES (within 5 min buffer)
  │     │
  │     ├─ Use refresh token
  │     │
  │     ├─ Get new access token
  │     │
  │     └─ Store new token
  │
  └─ Make API call with token

                    ▼ (More time passes)

Refresh Token Expires
  │
  ├─ Cannot refresh anymore
  │
  ├─ Clear all tokens
  │
  └─ Logout user → Show login screen
```

## 3. Platform-Specific Authentication

```
┌─────────────────────────────────────────────────────────────┐
│              Platform Detection & Routing                   │
└─────────────────────────────────────────────────────────────┘

App Startup
    │
    ├─ Platform.isWeb?
    │  └─ YES → WebAuthService
    │     ├─ OAuth2 Code Flow
    │     ├─ localStorage storage
    │     └─ Redirect: http://localhost:3000/callback
    │
    ├─ Platform.isAndroid?
    │  └─ YES → flutter_appauth
    │     ├─ OAuth2 with native browser
    │     ├─ Secure storage (encrypted)
    │     └─ Redirect: com.example.teste://callback
    │
    ├─ Platform.isIOS?
    │  └─ YES → flutter_appauth
    │     ├─ OAuth2 with native browser
    │     ├─ Keychain storage
    │     └─ Redirect: com.example.teste://callback
    │
    ├─ Platform.isWindows?
    │  └─ YES → flutter_appauth
    │     ├─ OAuth2 with system browser
    │     ├─ Secure storage
    │     └─ Redirect: http://localhost:8888/callback
    │
    ├─ Platform.isLinux?
    │  └─ YES → flutter_appauth
    │     ├─ OAuth2 with system browser
    │     ├─ Secure storage
    │     └─ Redirect: http://localhost:8888/callback
    │
    └─ Platform.isMacOS?
       └─ YES → flutter_appauth
          ├─ OAuth2 with system browser
          ├─ Keychain storage
          └─ Redirect: http://localhost:8888/callback
```

## 4. State Management Flow

```
┌──────────────────────────────────────────────────────────────┐
│              Provider State Management                       │
└──────────────────────────────────────────────────────────────┘

AuthProvider (ChangeNotifier)
    │
    ├─ State Variables
    │  ├─ _user: UserEntity?
    │  ├─ _isAuthenticated: bool
    │  ├─ _isLoading: bool
    │  └─ _error: String?
    │
    ├─ Public Methods
    │  ├─ initializeAuth()
    │  │  └─ Notifies listeners on change
    │  │
    │  ├─ authenticate()
    │  │  ├─ Calls AuthService.authenticate()
    │  │  ├─ Loads user info
    │  │  └─ Notifies listeners
    │  │
    │  ├─ logout()
    │  │  ├─ Calls AuthService.logout()
    │  │  ├─ Clears user data
    │  │  └─ Notifies listeners
    │  │
    │  └─ refreshUserInfo()
    │     ├─ Reloads user data
    │     └─ Notifies listeners
    │
    └─ Listeners (UI Widgets)
       ├─ AuthWrapper
       │  └─ Routes based on isAuthenticated
       │
       ├─ LoginScreen
       │  ├─ Shows loading state
       │  ├─ Shows error messages
       │  └─ Calls authenticate()
       │
       └─ ChatScreen
          ├─ Displays user info
          ├─ Calls logout()
          └─ Refreshes user info
```

## 5. Security Token Exchange

```
┌──────────────────────────────────────────────────────────────┐
│           OAuth2 Authorization Code Flow                     │
└──────────────────────────────────────────────────────────────┘

1. App Initiates Login
   └─ Redirects to Keycloak with:
      ├─ client_id: "web"
      ├─ response_type: "code"
      ├─ redirect_uri: "http://localhost:3000/callback"
      ├─ scope: "openid profile email"
      ├─ state: "<random_string>"
      └─ nonce: "<random_string>"

2. User Authenticates
   └─ Keycloak validates credentials
      └─ Generates authorization code

3. Keycloak Redirects
   └─ Redirects to app with:
      ├─ code: "<authorization_code>"
      ├─ state: "<same_random_string>"
      └─ session_state: "<session_state>"

4. App Validates State
   └─ Ensures state matches (CSRF protection)

5. App Exchanges Code for Tokens
   └─ POST to Keycloak token endpoint with:
      ├─ grant_type: "authorization_code"
      ├─ code: "<authorization_code>"
      ├─ client_id: "web"
      ├─ redirect_uri: "http://localhost:3000/callback"
      └─ (client_secret if confidential client)

6. Keycloak Returns Tokens
   └─ Response contains:
      ├─ access_token: "<JWT>"
      ├─ refresh_token: "<JWT>"
      ├─ id_token: "<JWT>"
      ├─ expires_in: 300 (seconds)
      └─ token_type: "Bearer"

7. App Stores Tokens
   └─ Securely stores in:
      ├─ flutter_secure_storage (mobile/desktop)
      └─ localStorage (web)

8. App Uses Access Token
   └─ For API calls:
      ├─ Authorization: "Bearer <access_token>"
      └─ Automatically refreshes before expiry
```

## 6. Error Handling Flow

```
┌──────────────────────────────────────────────────────────────┐
│              Error Handling & Recovery                       │
└──────────────────────────────────────────────────────────────┘

API Call
    │
    ├─ Check token validity
    │  │
    │  ├─ Token expired?
    │  │  └─ YES → Try refresh
    │  │     ├─ Refresh succeeds?
    │  │     │  ├─ YES → Use new token, retry API call
    │  │     │  └─ NO → Logout, show login screen
    │  │     └─ Error: "Token refresh failed"
    │  │
    │  └─ Token valid?
    │     └─ YES → Proceed with API call
    │
    ├─ Make API call
    │  │
    │  ├─ Success (200-299)?
    │  │  └─ Return data
    │  │
    │  ├─ Unauthorized (401)?
    │  │  ├─ Clear tokens
    │  │  ├─ Logout user
    │  │  └─ Show login screen
    │  │     Error: "Token expired or invalid"
    │  │
    │  ├─ Forbidden (403)?
    │  │  └─ Show error: "Access denied"
    │  │
    │  ├─ Network error?
    │  │  └─ Show error: "Connection failed"
    │  │
    │  └─ Other error?
    │     └─ Show error: "Request failed"
    │
    └─ Update UI with result
```

## 7. Component Interaction Diagram

```
┌──────────────────────────────────────────────────────────────┐
│           Component Interaction                              │
└──────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    UI Layer                                 │
│  ┌──────────────┐              ┌──────────────┐            │
│  │ LoginScreen  │              │ ChatScreen   │            │
│  └──────┬───────┘              └──────┬───────┘            │
│         │                             │                    │
│         └─────────────┬───────────────┘                    │
│                       │                                    │
└───────────────────────┼────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│              State Management Layer                         │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         AuthProvider (ChangeNotifier)               │  │
│  │  - Manages auth state                               │  │
│  │  - Notifies UI of changes                           │  │
│  │  - Handles user interactions                        │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                      │
└─────────────────────┼──────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│              Business Logic Layer                           │
│  ┌──────────────────────────────────────────────────────┐  │
│  │         AuthService                                 │  │
│  │  - OAuth2 flow                                       │  │
│  │  - Token management                                 │  │
│  │  - User info retrieval                              │  │
│  └──────────────────┬───────────────────────────────────┘  │
│                     │                                      │
└─────────────────────┼──────────────────────────────────────┘
                      │
        ┌─────────────┴──────────────┐
        │                            │
        ▼                            ▼
┌──────────────────┐      ┌──────────────────────┐
│ flutter_appauth  │      │ WebAuthService       │
│ (Mobile/Desktop) │      │ (Web/Chrome)         │
└────────┬─────────┘      └──────────┬───────────┘
         │                           │
         └───────────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │   Keycloak Server      │
            │   (Auth Provider)      │
            │   localhost:8080       │
            └────────────────────────┘
```

---

These diagrams show:
1. **Application Flow** - How the app initializes and routes
2. **Token Lifecycle** - How tokens are managed over time
3. **Platform Support** - How different platforms are handled
4. **State Management** - How state flows through the app
5. **Security** - How OAuth2 token exchange works
6. **Error Handling** - How errors are caught and handled
7. **Components** - How different layers interact

