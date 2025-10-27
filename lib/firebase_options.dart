import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // Agar aap web ke liye build nahi kar rahe to iski chinta na karein
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ⬇️===== YEH AAPKE SCREENSHOT SE LI GAYI HAIN =====⬇️
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCdB9TjSG-obv-_AN429UP6-XpiAM_SmJ0",
    appId: "1:265258409167:android:bc2097306eb0c51e6b6bba",
    messagingSenderId: "265258409167",
    projectId: "instaquiz-9cc2f",
    storageBucket: "instaquiz-9cc2f.firebasestorage.app", // (Aapki purani file se liya)
    androidPackageName: "com.opkukna.exambeing", // (Yeh hai asli fix)
  );
  // ⬆️=================================================⬆️

  // (Yeh dummy web values hain, aapke Android app par iska fark nahi padega)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCdB9TjSG-obv-_AN429UP6-XpiAM_SmJ0",
    appId: "1:265258409167:web:dummydummydummy", // Not used
    messagingSenderId: "265258409167",
    projectId: "instaquiz-9cc2f",
    authDomain: "instaquiz-9cc2f.firebaseapp.com",
    storageBucket: "instaquiz-9cc2f.firebasestorage.app",
  );
}
