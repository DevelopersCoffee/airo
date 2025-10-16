import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;

/// Web-specific OAuth2 authentication handler for Chrome/Browser
/// This service handles OAuth2 implicit flow for web applications
class WebAuthService {
  static const String _keycloakUrl = 'http://localhost:8080';
  static const String _realm = 'example';
  static const String _clientId = 'web';
  static const String _redirectUrl = 'http://localhost:3000/callback';
  static const List<String> _scopes = ['openid', 'profile', 'email'];

  /// Generate OAuth2 authorization URL for web
  static String getAuthorizationUrl({
    String? state,
    String? nonce,
  }) {
    final params = {
      'client_id': _clientId,
      'response_type': 'code',
      'redirect_uri': _redirectUrl,
      'scope': _scopes.join(' '),
      'state': state ?? _generateRandomString(32),
      'nonce': nonce ?? _generateRandomString(32),
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_keycloakUrl/realms/$_realm/protocol/openid-connect/auth?$queryString';
  }

  /// Exchange authorization code for tokens
  static Future<Map<String, dynamic>> exchangeCodeForToken(String code) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
        ),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'client_id': _clientId,
          'code': code,
          'redirect_uri': _redirectUrl,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body) as Map<String, dynamic>;
        developer.log('Token exchange successful', name: 'WebAuthService');
        return tokenData;
      } else {
        throw Exception(
          'Token exchange failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Token exchange error: $e', name: 'WebAuthService');
      rethrow;
    }
  }

  /// Refresh access token using refresh token
  static Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_keycloakUrl/realms/$_realm/protocol/openid-connect/token',
        ),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'client_id': _clientId,
          'refresh_token': refreshToken,
        },
      );

      if (response.statusCode == 200) {
        final tokenData = json.decode(response.body) as Map<String, dynamic>;
        developer.log('Token refresh successful', name: 'WebAuthService');
        return tokenData;
      } else {
        throw Exception(
          'Token refresh failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      developer.log('Token refresh error: $e', name: 'WebAuthService');
      rethrow;
    }
  }

  /// Get logout URL
  static String getLogoutUrl({String? redirectUrl}) {
    final params = {
      'redirect_uri': redirectUrl ?? _redirectUrl,
    };

    final queryString = params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');

    return '$_keycloakUrl/realms/$_realm/protocol/openid-connect/logout?$queryString';
  }

  /// Decode JWT token (without verification - for client-side use only)
  static Map<String, dynamic> decodeToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        throw Exception('Invalid token format');
      }

      // Decode payload (second part)
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));

      return json.decode(decoded) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Token decode error: $e', name: 'WebAuthService');
      rethrow;
    }
  }

  /// Check if token is expired
  static bool isTokenExpired(String token) {
    try {
      final claims = decodeToken(token);
      final exp = claims['exp'] as int?;

      if (exp == null) return true;

      final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      final buffer = const Duration(minutes: 5);

      return DateTime.now().add(buffer).isAfter(expirationTime);
    } catch (e) {
      developer.log('Token expiration check error: $e', name: 'WebAuthService');
      return true;
    }
  }

  /// Generate random string for state/nonce
  static String _generateRandomString(int length) {
    const chars =
        'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();

    for (int i = 0; i < length; i++) {
      buffer.write(chars[(random + i) % chars.length]);
    }

    return buffer.toString();
  }
}

