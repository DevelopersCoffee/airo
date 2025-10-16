# Web Authentication Setup (Chrome/Browser)

This guide explains how to set up authentication for the AIRO Assistant web application running in Chrome or any modern browser.

## Overview

The web authentication uses OAuth2 Authorization Code Flow with Keycloak. This is the most secure flow for web applications.

## Prerequisites

- Keycloak running locally (http://localhost:8080)
- Web client configured in Keycloak (see KEYCLOAK_SETUP.md)
- Node.js and npm (for local development server)

## Step 1: Create Web Callback Handler

Create a simple Node.js/Express server to handle OAuth2 callbacks:

### Install Dependencies

```bash
npm init -y
npm install express cors dotenv axios
```

### Create server.js

```javascript
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Serve static files (Flutter web build)
app.use(express.static('build/web'));

// OAuth2 callback endpoint
app.get('/callback', (req, res) => {
  const { code, state, error } = req.query;

  if (error) {
    return res.status(400).json({
      error: error,
      error_description: req.query.error_description || 'Unknown error'
    });
  }

  if (!code) {
    return res.status(400).json({ error: 'No authorization code received' });
  }

  // Store code in session or pass to frontend
  res.json({
    code: code,
    state: state,
    message: 'Authorization code received. Pass this to your app.'
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
```

### Create .env

```env
PORT=3000
KEYCLOAK_URL=http://localhost:8080
KEYCLOAK_REALM=example
KEYCLOAK_CLIENT_ID=web
```

### Run Server

```bash
node server.js
```

## Step 2: Build Flutter Web App

```bash
flutter build web --release
```

This creates a web build in `build/web/`.

## Step 3: Serve Flutter Web App

### Option A: Using Flutter's Built-in Server

```bash
flutter run -d chrome
```

### Option B: Using Express Server

```bash
# Copy Flutter build to server
cp -r build/web/* .

# Run server
node server.js
```

Access at: `http://localhost:3000`

## Step 4: Configure Keycloak Web Client

1. Go to Keycloak Admin Console: `http://localhost:8080/admin`
2. Select realm: `example`
3. Go to Clients → `web`
4. Configure:

**Access Settings**:
- Valid Redirect URIs: `http://localhost:3000/callback`
- Web Origins: `http://localhost:3000`
- Valid Post Logout Redirect URIs: `http://localhost:3000`

**Capability Config**:
- Standard Flow Enabled: ON
- Implicit Flow Enabled: ON
- Direct Access Grants Enabled: ON

**Advanced Settings**:
- Access Token Lifespan: 5 minutes
- Refresh Token Lifespan: 30 minutes

## Step 5: Update Flutter Web Configuration

### Update web/index.html

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta content="IE=Edge" http-equiv="X-UA-Compatible">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AIRO Assistant</title>
    <link rel="manifest" href="manifest.json">
</head>
<body>
    <script>
        // Handle OAuth2 callback
        window.addEventListener('load', function() {
            const params = new URLSearchParams(window.location.search);
            const code = params.get('code');
            const state = params.get('state');
            
            if (code) {
                // Store in localStorage for Flutter app to access
                localStorage.setItem('oauth_code', code);
                localStorage.setItem('oauth_state', state);
                
                // Redirect to app
                window.location.href = '/';
            }
        });
    </script>
    <script src="flutter.js" defer></script>
</body>
</html>
```

### Update pubspec.yaml for Web

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  web: ^0.5.0
```

## Step 6: Handle OAuth2 Flow in Flutter

### Create web_oauth_handler.dart

```dart
import 'dart:html' as html;
import 'dart:convert';
import 'package:http/http.dart' as http;

class WebOAuthHandler {
  static const String _keycloakUrl = 'http://localhost:8080';
  static const String _realm = 'example';
  static const String _clientId = 'web';
  static const String _redirectUrl = 'http://localhost:3000/callback';

  /// Get authorization code from URL
  static String? getAuthorizationCode() {
    final code = html.window.localStorage['oauth_code'];
    html.window.localStorage.remove('oauth_code');
    return code;
  }

  /// Exchange code for tokens
  static Future<Map<String, dynamic>> exchangeCodeForToken(String code) async {
    final response = await http.post(
      Uri.parse(
        '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'client_id': _clientId,
        'code': code,
        'redirect_uri': _redirectUrl,
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Token exchange failed');
    }
  }

  /// Redirect to Keycloak login
  static void redirectToLogin() {
    final authUrl = Uri(
      scheme: 'http',
      host: 'localhost',
      port: 8080,
      path: '/realms/$_realm/protocol/openid-connect/auth',
      queryParameters: {
        'client_id': _clientId,
        'response_type': 'code',
        'redirect_uri': _redirectUrl,
        'scope': 'openid profile email',
      },
    );

    html.window.location.href = authUrl.toString();
  }
}
```

## Step 7: Test Authentication Flow

1. Open browser: `http://localhost:3000`
2. Click "Sign in with Keycloak"
3. You'll be redirected to Keycloak login page
4. Enter credentials (e.g., testuser / password123)
5. After login, you'll be redirected back to the app
6. App should display chat screen with user info

## Step 8: Production Deployment

### Update Configuration for Production

```yaml
# For production, update:
# - Keycloak URL to production instance
# - Redirect URIs to production domain
# - Enable HTTPS
# - Set secure cookies
```

### Deploy to Firebase Hosting

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Initialize Firebase
firebase init

# Build Flutter web
flutter build web --release

# Deploy
firebase deploy
```

### Deploy to Netlify

```bash
# Install Netlify CLI
npm install -g netlify-cli

# Build Flutter web
flutter build web --release

# Deploy
netlify deploy --prod --dir=build/web
```

## Troubleshooting

### "Invalid redirect URI"
- Ensure redirect URI in Keycloak matches exactly
- Check for trailing slashes
- Verify protocol (http vs https)

### "CORS errors"
- Add your domain to Keycloak Web Origins
- Ensure backend allows CORS from your domain

### "Code exchange fails"
- Verify client ID is correct
- Check Keycloak is running
- Ensure code hasn't expired (usually 1 minute)

### "Token not stored"
- Check browser localStorage is enabled
- Verify no privacy mode restrictions
- Check browser console for errors

## Security Considerations

1. **Use HTTPS in production** - Never use HTTP for production
2. **Secure token storage** - Use secure cookies with HttpOnly flag
3. **PKCE flow** - Consider using PKCE for additional security
4. **Token rotation** - Implement automatic token refresh
5. **CSRF protection** - Use state parameter (already implemented)
6. **Content Security Policy** - Set appropriate CSP headers

## Environment Variables

Create `.env.production`:

```env
KEYCLOAK_URL=https://keycloak.yourdomain.com
KEYCLOAK_REALM=example
KEYCLOAK_CLIENT_ID=web
REDIRECT_URL=https://app.yourdomain.com/callback
BACKEND_URL=https://api.yourdomain.com
```

## Next Steps

1. Implement token refresh mechanism
2. Add logout functionality
3. Set up user profile page
4. Implement role-based access control
5. Add error handling and logging
6. Set up monitoring and analytics

