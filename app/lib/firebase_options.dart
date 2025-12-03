// File generated for Firebase configuration
// To get web config: Firebase Console → Project Settings → Your apps → Web app
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
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

  // Web configuration - from Firebase Console
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXwAHFzEmvM0VMq_OVR-J_rm3aemlmq5A',
    appId: '1:906799550225:web:28533fb091ebbb3d2206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    authDomain: 'devscoffee-airo.firebaseapp.com',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  // Android configuration - from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId: '1:906799550225:android:8052938d459ef9832206b0',
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
  );

  // iOS configuration - TODO: Add from GoogleService-Info.plist
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId:
        '1:906799550225:ios:YOUR_IOS_APP_ID', // TODO: Get from Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
    iosBundleId: 'com.developerscoffee.airo',
  );

  // macOS configuration
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyCBhj62CjX9G7-QNbF3e-53BiM3FYcWNxw',
    appId:
        '1:906799550225:ios:YOUR_MACOS_APP_ID', // TODO: Get from Firebase Console
    messagingSenderId: '906799550225',
    projectId: 'devscoffee-airo',
    storageBucket: 'devscoffee-airo.firebasestorage.app',
    iosBundleId: 'com.developerscoffee.airo',
  );

  // Windows configuration
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
