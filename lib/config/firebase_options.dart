// Synced with FlutterFire project: crickflow-b06bc
// Regenerate: flutterfire configure
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('CrickFlow mobile only in Phase 1');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCHRvYTM7weKV8MhiBcEQ16LNH6Hd0Csq8',
    appId: '1:202403125129:android:feae8423682b0b9c37b358',
    messagingSenderId: '202403125129',
    projectId: 'crickflow-b06bc',
    storageBucket: 'crickflow-b06bc.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBem5ugk3fGc7HiaHO9pCbqxt43fCuoe7Q',
    appId: '1:202403125129:ios:031dba2e4db98d7237b358',
    messagingSenderId: '202403125129',
    projectId: 'crickflow-b06bc',
    storageBucket: 'crickflow-b06bc.firebasestorage.app',
    iosBundleId: 'com.mavixas.crickflow',
  );
}
