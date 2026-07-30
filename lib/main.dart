import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/firebase_options.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'data/local/match_local_store.dart';
import 'data/services/admob_service.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/theme_service.dart';
import 'shared/providers/offline_sync_provider.dart';
import 'shared/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseBootstrap.configure();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  // Keep Crashlytics off in debug to avoid noise; on in release/profile.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(!kDebugMode);

  // Non-blocking — ads must never delay app start.
  unawaited(AdMobService.initialize());

  final matchLocalStore = MatchLocalStore();
  await matchLocalStore.init();
  final connectivityService = ConnectivityService();
  await connectivityService.init();

  final prefs = await SharedPreferences.getInstance();
  final themeService = ThemeService(prefs: prefs);
  final initialThemeMode = themeService.readThemeMode(prefs);

  runApp(
    ProviderScope(
      overrides: [
        matchLocalStoreProvider.overrideWithValue(matchLocalStore),
        connectivityServiceProvider.overrideWithValue(connectivityService),
        themeServiceProvider.overrideWithValue(themeService),
        themeModeProvider.overrideWith(
          (ref) => ThemeModeNotifier(
            ref.watch(themeServiceProvider),
            initialThemeMode,
          ),
        ),
      ],
      child: const CrickFlowApp(),
    ),
  );
}
