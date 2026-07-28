// File generated for CrickFlow Super Admin web app.
// Firebase project: crickflow-b06bc
// App: CrickFlow Super Admin (web:858c953b1c7b883037b358)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        throw UnsupportedError(
          'CrickFlow Super Admin is a Flutter Web application only.',
        );
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDdA6_q5js8nOzpQ593_o56mHi8Zj5C4Zk',
    appId: '1:202403125129:web:858c953b1c7b883037b358',
    messagingSenderId: '202403125129',
    projectId: 'crickflow-b06bc',
    authDomain: 'crickflow-b06bc.firebaseapp.com',
    storageBucket: 'crickflow-b06bc.firebasestorage.app',
    measurementId: 'G-WCMVPZ0WGP',
  );
}
