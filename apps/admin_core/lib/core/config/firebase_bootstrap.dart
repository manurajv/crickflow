import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Initializes Firebase for an admin web panel.
///
/// Pass the app-specific [FirebaseOptions] from each project's
/// `firebase_options.dart`. Does not touch the mobile app options.
Future<void> bootstrapFirebase(FirebaseOptions options) async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(options: options);
  if (kDebugMode) {
    debugPrint('Firebase initialized for project ${options.projectId}');
  }
}
