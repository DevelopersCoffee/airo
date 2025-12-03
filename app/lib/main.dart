import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app/airo_app.dart';
import 'core/auth/auth_service.dart';
import 'firebase_options.dart';

/// Global flag to track if Firebase is available
bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with platform-specific options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    isFirebaseInitialized = false;
    debugPrint('⚠️ Firebase initialization failed: $e');
    debugPrint(
      '📝 Demo login (admin/admin) available. Google Sign-In needs Firebase.',
    );
  }

  // Initialize AuthService
  await AuthService.instance.initialize();

  runApp(const ProviderScope(child: AiroApp()));
}
