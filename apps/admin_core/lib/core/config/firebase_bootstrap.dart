import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Local-only: `--dart-define=ADMIN_USE_EMULATORS=true` points Auth and
/// Firestore at the Firebase emulators (default host 127.0.0.1, ports 9099 /
/// 8080). Never set this for a production build.
const bool kAdminUseEmulators = bool.fromEnvironment('ADMIN_USE_EMULATORS');
const String _emulatorHost = String.fromEnvironment(
  'ADMIN_EMULATOR_HOST',
  defaultValue: '127.0.0.1',
);

/// Initializes Firebase for an admin web panel.
///
/// Pass the app-specific [FirebaseOptions] from each project's
/// `firebase_options.dart`. Does not touch the mobile app options.
Future<void> bootstrapFirebase(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
  if (kAdminUseEmulators) {
    await FirebaseAuth.instance.useAuthEmulator(_emulatorHost, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(_emulatorHost, 8080);
    debugPrint('Admin panel using Firebase emulators at $_emulatorHost');
  }
  if (kDebugMode) {
    debugPrint('Firebase initialized for project ${options.projectId}');
  }
}
