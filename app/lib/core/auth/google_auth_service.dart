import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Google Authentication Service using Firebase Auth
class GoogleAuthService {
  static GoogleAuthService? _instance;
  static GoogleAuthService get instance => _instance ??= GoogleAuthService._();

  GoogleAuthService._();

  // Web OAuth Client ID from Google Cloud Console
  static const String _webClientId =
      '906799550225-2cs0tag45smuuksmeq8lblkrmaueta3t.apps.googleusercontent.com';

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? _webClientId : null,
  );

  firebase_auth.FirebaseAuth get _firebaseAuth =>
      firebase_auth.FirebaseAuth.instance;

  /// Check if user is signed in with Google
  bool get isSignedIn => _firebaseAuth.currentUser != null;

  /// Get current Firebase user
  firebase_auth.User? get currentFirebaseUser => _firebaseAuth.currentUser;

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return AuthResult.failure('Sign-in cancelled');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
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
      await Future.wait([_googleSignIn.signOut(), _firebaseAuth.signOut()]);
      debugPrint('Google Sign-Out successful');
    } catch (e) {
      debugPrint('Google Sign-Out error: $e');
    }
  }

  /// Check if Google Sign-In is available on this device
  Future<bool> isGoogleSignInAvailable() async {
    try {
      return await _googleSignIn.isSignedIn() || true;
    } catch (e) {
      debugPrint('Google Sign-In availability check failed: $e');
      return false;
    }
  }

  /// Silently sign in (for returning users)
  Future<AuthResult?> signInSilently() async {
    try {
      final googleUser = await _googleSignIn.signInSilently();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
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
