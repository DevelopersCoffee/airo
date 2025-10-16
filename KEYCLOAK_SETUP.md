# Keycloak Setup Guide for AIRO Assistant

This guide explains how to configure Keycloak for authentication with the AIRO Assistant application across web (Chrome), mobile (Flutter), and desktop platforms.

## Prerequisites

- Docker and Docker Compose installed
- Keycloak running locally (see `keycloak/docker-compose.yaml`)
- Admin access to Keycloak

## Quick Start

### 1. Start Keycloak

```bash
cd keycloak
docker-compose up -d
```

Access Keycloak Admin Console at: `http://localhost:8080/admin`

Default credentials (from `.env`):
- Username: `admin`
- Password: `admin`

### 2. Create a Realm

1. Go to Admin Console
2. Click "Master" dropdown → "Create Realm"
3. Name: `example`
4. Click "Create"

## Configure Clients

### A. Web Client (Chrome/Browser)

**Purpose**: For web-based access via Chrome

1. Navigate to: Realm Settings → Clients → Create
2. **Client ID**: `web`
3. **Client Protocol**: `openid-connect`
4. **Access Type**: `public`
5. Click "Save"

**Configure Web Client**:
- **Valid Redirect URIs**: 
  - `http://localhost:3000/callback`
  - `http://localhost:3000/*`
- **Web Origins**: `http://localhost:3000`
- **Standard Flow Enabled**: ON
- **Implicit Flow Enabled**: ON
- **Direct Access Grants Enabled**: ON

### B. Mobile Client (Android/iOS)

**Purpose**: For native mobile apps

1. Navigate to: Realm Settings → Clients → Create
2. **Client ID**: `mobile`
3. **Client Protocol**: `openid-connect`
4. **Access Type**: `public`
5. Click "Save"

**Configure Mobile Client**:
- **Valid Redirect URIs**:
  - `com.example.teste://callback`
  - `com.developerscoffee.airo://callback`
- **Standard Flow Enabled**: ON
- **Implicit Flow Enabled**: ON
- **Direct Access Grants Enabled**: ON

### C. Desktop Client (Windows/Linux/macOS)

**Purpose**: For desktop applications

1. Navigate to: Realm Settings → Clients → Create
2. **Client ID**: `desktop`
3. **Client Protocol**: `openid-connect`
4. **Access Type**: `public`
5. Click "Save"

**Configure Desktop Client**:
- **Valid Redirect URIs**:
  - `http://localhost:8888/callback`
  - `http://localhost:8888/*`
- **Standard Flow Enabled**: ON
- **Implicit Flow Enabled**: ON
- **Direct Access Grants Enabled**: ON

## Configure Scopes

1. Go to: Realm Settings → Client Scopes
2. Ensure these scopes exist:
   - `openid` (default)
   - `profile` (default)
   - `email` (default)

## Create Test Users

1. Go to: Users → Add User
2. **Username**: `testuser`
3. **Email**: `testuser@example.com`
4. **First Name**: `Test`
5. **Last Name**: `User`
6. Click "Save"

**Set Password**:
1. Go to "Credentials" tab
2. Set password: `password123`
3. Toggle "Temporary" to OFF
4. Click "Set Password"

## Configure User Roles (Optional)

1. Go to: Roles → Add Role
2. Create roles like: `admin`, `user`, `moderator`
3. Assign roles to users via Users → Select User → Role Mappings

## Backend Configuration (Java/Spring Boot)

### Add Dependencies

```xml
<dependency>
    <groupId>org.keycloak</groupId>
    <artifactId>keycloak-spring-boot-starter</artifactId>
    <version>26.4.0</version>
</dependency>
```

### application.yml Configuration

```yaml
keycloak:
  realm: example
  auth-server-url: http://localhost:8080
  ssl-required: none
  resource: backend
  credentials:
    secret: <client-secret-from-keycloak>
  use-resource-role-mappings: true

spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: http://localhost:8080/realms/example
          jwk-set-uri: http://localhost:8080/realms/example/protocol/openid-connect/certs
```

### Create Backend Client

1. Navigate to: Realm Settings → Clients → Create
2. **Client ID**: `backend`
3. **Client Protocol**: `openid-connect`
4. **Access Type**: `confidential`
5. Click "Save"

**Configure Backend Client**:
- **Valid Redirect URIs**: `http://localhost:8080/*`
- **Service Accounts Enabled**: ON
- Copy the **Client Secret** from "Credentials" tab

## Flutter Configuration

The app automatically detects the platform and uses the appropriate client:

- **Android**: Uses `mobile` client with redirect `com.example.teste://callback`
- **iOS**: Uses `mobile-ios` client with redirect `com.example.teste://callback`
- **Web**: Uses `web` client with redirect `http://localhost:3000/callback`
- **Desktop**: Uses `desktop` client with redirect `http://localhost:8888/callback`

### Android Configuration

Update `android/app/build.gradle.kts`:

```kotlin
manifestPlaceholders += [
    'appAuthRedirectScheme': 'com.developerscoffee.airo'
]
```

### iOS Configuration

Update `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.example.teste</string>
        </array>
    </dict>
</array>
```

## Testing Authentication

### Test with Flutter

```bash
flutter run
```

The app will:
1. Check if user is authenticated
2. If not, show login screen
3. On login button click, open Keycloak login page
4. After successful login, redirect back to app
5. Load user info and show chat screen

### Test with Web (Chrome)

```bash
flutter run -d chrome
```

### Test with Desktop

```bash
flutter run -d windows
# or
flutter run -d linux
# or
flutter run -d macos
```

## Troubleshooting

### "Invalid redirect URI"
- Ensure the redirect URI in Keycloak matches exactly with the app configuration
- Check for trailing slashes and protocol (http vs https)

### "Token expired"
- The app automatically refreshes tokens 5 minutes before expiration
- If refresh fails, user is logged out

### "CORS errors"
- Add CORS configuration to Keycloak realm settings
- Allowed Origins: `http://localhost:3000`, `http://localhost:8080`

### "Connection refused"
- Ensure Keycloak is running: `docker-compose ps`
- Check if port 8080 is available
- Verify network connectivity

## Security Notes

1. **Never commit secrets** to version control
2. **Use HTTPS in production** (set `KC_HOSTNAME_STRICT_HTTPS: true`)
3. **Rotate client secrets** regularly
4. **Use strong passwords** for test users
5. **Enable MFA** for production environments
6. **Configure token expiration** appropriately (default: 5 minutes)

## Environment Variables

Create `.env` file in `keycloak/` directory:

```env
POSTGRES_DB=keycloak
POSTGRES_USER=keycloak
POSTGRES_PASSWORD=keycloak_password
KEYCLOAK_ADMIN=admin
KEYCLOAK_ADMIN_PASSWORD=admin_password
```

## Next Steps

1. Configure your backend API to validate tokens
2. Set up user profile endpoints
3. Implement role-based access control (RBAC)
4. Add MFA for production
5. Configure email verification

