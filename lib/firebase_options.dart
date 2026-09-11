// lib/firebase_options.dart
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

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
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ✅ Configuration pour le Web (avec vos vraies valeurs)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAVMsS3Z8MBzZPBnJUfT9LjAs3YAC12L6Q',
    authDomain: 'syndic-163b9.firebaseapp.com',
    projectId: 'syndic-163b9',
    storageBucket: 'syndic-163b9.firebasestorage.app',
    messagingSenderId: '233447789411',
    appId: '1:233447789411:web:69dd31bee0b6be76527956',
    measurementId: 'G-4VYXCTHY2H',
  );

  // ✅ Configuration pour Android (à compléter avec vos valeurs Android)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAVMsS3Z8MBzZPBnJUfT9LjAs3YAC12L6Q', // Même clé API
    authDomain: 'syndic-163b9.firebaseapp.com',
    projectId: 'syndic-163b9',
    storageBucket: 'syndic-163b9.firebasestorage.app',
    messagingSenderId: '233447789411',
    appId: '1:233447789411:android:VOTRE_APP_ID_ANDROID', // À remplacer
  );

  // ✅ Configuration pour iOS (à compléter avec vos valeurs iOS)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAVMsS3Z8MBzZPBnJUfT9LjAs3YAC12L6Q',
    authDomain: 'syndic-163b9.firebaseapp.com',
    projectId: 'syndic-163b9',
    storageBucket: 'syndic-163b9.firebasestorage.app',
    messagingSenderId: '233447789411',
    appId: '1:233447789411:ios:VOTRE_APP_ID_IOS', // À remplacer
  );

  // ✅ Configuration pour Windows (à compléter avec vos valeurs Windows)
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyAVMsS3Z8MBzZPBnJUfT9LjAs3YAC12L6Q',
    authDomain: 'syndic-163b9.firebaseapp.com',
    projectId: 'syndic-163b9',
    storageBucket: 'syndic-163b9.firebasestorage.app',
    messagingSenderId: '233447789411',
    appId: '1:233447789411:windows:VOTRE_APP_ID_WINDOWS', // À remplacer
  );

  // ✅ Configuration pour macOS (à compléter avec vos valeurs macOS)
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAVMsS3Z8MBzZPBnJUfT9LjAs3YAC12L6Q',
    authDomain: 'syndic-163b9.firebaseapp.com',
    projectId: 'syndic-163b9',
    storageBucket: 'syndic-163b9.firebasestorage.app',
    messagingSenderId: '233447789411',
    appId: '1:233447789411:macos:VOTRE_APP_ID_MACOS', // À remplacer
  );
}