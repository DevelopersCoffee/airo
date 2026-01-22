import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Google Authentication Service using Firebase Auth
/// Updated for google_sign_in 7.x API
class GoogleAuthService {
  static GoogleAuthService? _instance;
  static GoogleAuthService get instance => _instance ??= GoogleAuthService._();

  GoogleAuthService._();

  // Web OAuth Client ID from Google Cloud Console
  static const String _webClientId =
      '906799550225-2cs0tag45smuuksmeq8lblkrmaueta3t.apps.googleusercontent.com';

  // google_sign_in 7.x: Use singleton instance
  GoogleSignIn get _googleSignIn => GoogleSignIn.instance;

  bool _isInitialized = false;

  firebase_auth.FirebaseAuth get _firebaseAuth =>
      firebase_auth.FirebaseAuth.instance;

  /// Check if user is signed in with Google
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Get current Firebase user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Initialize GoogleSignIn - must be called before any other methods
  /// google_sign_in 7.x requires explicit initialization
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _googleSignIn.initialize(
        clientId: kIsWeb ? _webClientId : null,
        serverClientId: null,
      );
      _isInitialized = true;
      debugPrint('GoogleSignIn initialized successfully');
    } catch (e) {
      debugPrint('GoogleSignIn initialization failed: $e');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Ensure initialized
      await initialize();

      // google_sign_in 7.x: authenticate() returns the account (throws on cancel)
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await _googleSignIn.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return AuthResult.failure('Sign-in cancelled');
        }
        rethrow;
      }

      // google_sign_in 7.x: Get tokens via authorizationClient
      final authResult = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      // Create a new credential using the tokens
      // Note: For Firebase, we need idToken which comes from authorization
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: authResult.accessToken,
        // idToken may not be available in all cases with 7.x
        // Firebase can work with just accessToken for some flows
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );

      final firebaseUser = userCredential.user;
      if (firebaseUser == null) {
        return AuthResult.failure('Failed to sign in with Google');
      }

      // Create local User from Firebase user
      final user = User(
        id: firebaseUser.uid,
        username: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
        isAdmin: false,
        isGoogleUser: true,
        createdAt: DateTime.now(),
      );

      // Save to local auth service
      await AuthService.instance.setGoogleUser(user);

      debugPrint('Google Sign-In successful: ${user.username}');
      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return AuthResult.failure('Google Sign-In failed: ${e.toString()}');
    }
  }

  /// Sign out from Google and Firebase
  Future<void> signOut() async {
    try {
      await initialize();
      await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
      debugPrint('Google Sign-Out successful');
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }

  /// Check if Google Sign-In is available on this device
  Future<bool> isGoogleSignInAvailable() async {
    try {
      await initialize();
      // google_sign_in 7.x: supportsAuthenticate checks platform support
      return _googleSignIn.supportsAuthenticate();
    } catch (e) {
      debugPrint('Google Sign-In availability check failed: $e');
      return false;
    }
  }

  /// Silently sign in (for returning users)
  /// google_sign_in 7.x: Use attemptLightweightAuthentication
  Future<AuthResult?> signInSilently() async {
    try {
      await initialize();

      // google_sign_in 7.x: attemptLightweightAuthentication for silent sign-in
      final googleUser = await _googleSignIn.attemptLightweightAuthentication();
      if (googleUser == null) return null;

      // Get access token for Firebase
      final authResult = await googleUser.authorizationClient.authorizeScopes([
        'email',
        'profile',
      ]);

      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: authResult.accessToken,
        // idToken not directly available in 7.x, Firebase works with accessToken
      );

      final userCredential = await _firebaseAuth.signInWithCredential(
        credential,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) return null;

      final user = User(
        id: firebaseUser.uid,
        username: firebaseUser.displayName ?? firebaseUser.email ?? 'User',
        email: firebaseUser.email,
        photoUrl: firebaseUser.photoURL,
        isAdmin: false,
        isGoogleUser: true,
        createdAt: DateTime.now(),
      );

      await AuthService.instance.setGoogleUser(user);
      return AuthResult.success(user);
    } catch (e) {
      debugPrint('Silent sign-in failed: $e');
      return null;
    }
  }
}
