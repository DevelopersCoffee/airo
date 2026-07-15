// Firebase configuration with multi-platform variant support
// Supports: Mobile Full (io.airo.app), Mobile Streaming (io.airo.app.streaming), Android TV (io.airo.app.tv)
//
// To configure:
// 1. Register all package IDs in Firebase Console under the same project
// 2. Download combined google-services.json (contains all package IDs)
// 3. Update appId values below after registering new apps
//
// Build with variant:
//   flutter build apk --dart-define=APP_VARIANT=tv
//   flutter build apk --dart-define=APP_VARIANT=streaming
//   flutter build apk --dart-define=APP_VARIANT=full (default)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// App variant for Firebase configuration selection
// Set via --dart-define=APP_VARIANT=<value>
enum AppVariant {
  full, // io.airo.app - All features
  streaming, // io.airo.app.streaming - Music + IPTV
  tv, // io.airo.app.tv - IPTV only
}

/// Default [FirebaseOptions] for use with your Firebase apps.
/// Supports multiple Android app variants under the same Firebase project.
class DefaultFirebaseOptions {
  /// Current app variant from dart-define
  static const String _variantString = String.fromEnvironment(
    'APP_VARIANT',
    defaultValue: 'full',
  );

  /// Get the current app variant
  static AppVariant get currentVariant {
    switch (_variantString) {
      case 'tv':
        return AppVariant.tv;
      case 'streaming':
        return AppVariant.streaming;
      default:
        return AppVariant.full;
    }
  }

  /// Returns false for generated placeholder options that would crash native
  /// Firebase initialization before Dart can recover.
  static bool isConfigured(FirebaseOptions options) {
    return _isConfigured(options);
  }

  /// Get Firebase options for the current platform and variant
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _getAndroidOptions();
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Whether the selected platform has a real Firebase app id configured.
  ///
  /// The iOS/macOS/windows entries currently use placeholder app ids. Passing
  /// those placeholders into Firebase iOS causes a native NSException before
  /// Dart can handle the error, so callers should skip initialization when this
  /// returns false.
  static bool get isCurrentPlatformConfigured {
    if (kIsWeb) {
      return _isConfigured(web);
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _isConfigured(_getAndroidOptions());
      case TargetPlatform.iOS:
        return _isConfigured(ios);
      case TargetPlatform.macOS:
        return _isConfigured(macos);
      case TargetPlatform.windows:
        return _isConfigured(windows);
      case TargetPlatform.linux:
        return false;
      default:
        return false;
    }
  }

  static bool _isConfigured(FirebaseOptions options) {
    final appId = options.appId;
    return appId.isNotEmpty &&
        !appId.contains('YOUR_') &&
        !appId.contains('TODO');
  }

  /// Get Android options based on current build variant
  static FirebaseOptions _getAndroidOptions() {
    switch (currentVariant) {
      case AppVariant.tv:
        return androidTv;
      case AppVariant.streaming:
        return androidStreaming;
      case AppVariant.full:
        return android;
    }
  }

  // ===========================================================================
  // Web Configuration
  // ===========================================================================
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXwAHFzEmvM0VMq_OVR-J_rm3aemlmq5A',
    appId: '1:906799550225:web:28533fb091ebbb3d2206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    authDomain: 'devscoffee-airo.firebaseapp.com',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  // ===========================================================================
  // Android Configurations (Multiple variants, same Firebase project)
  // ===========================================================================

  /// Android Mobile Full - io.airo.app (existing)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:8052938d459ef9832206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  /// Android TV - io.airo.app.tv
  static const FirebaseOptions androidTv = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:dfa957aac3a2fdc62206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  /// Android Streaming - io.airo.app.streaming
  ///
  /// Update this after downloading the Firebase client config for the
  /// registered io.airo.app.streaming Android app.
  static const FirebaseOptions androidStreaming = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: 'TODO_REGISTER_IO_AIRO_APP_STREAMING',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  // ===========================================================================
  // iOS Configuration
  // ===========================================================================
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId:
        '1:906799550225:ios:YOUR_IOS_APP_ID', // TODO: Get from Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
    iosBundleId: 'com.developerscoffee.airo',
  );

  // ===========================================================================
  // Desktop Configurations
  // ===========================================================================
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId:
        '1:906799550225:ios:YOUR_MACOS_APP_ID', // TODO: Get from Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
    iosBundleId: 'com.developerscoffee.airo',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId:
        '1:906799550225:web:YOUR_WINDOWS_APP_ID', // TODO: Get from Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    authDomain: 'devscoffee-airo.firebaseapp.com',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );
}
