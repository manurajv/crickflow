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
import 'core/startup/startup_trace.dart';
import 'data/local/match_local_store.dart';
import 'data/services/admob_service.dart';
import 'data/services/connectivity_service.dart';
import 'data/services/theme_service.dart';
import 'shared/providers/offline_sync_provider.dart';
import 'shared/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('binding');
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  StartupTrace.mark('firebase');
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
  // Not needed before the first frame.
  unawaited(
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(!kDebugMode),
  );

  // Non-blocking — ads must never delay app start.
  unawaited(AdMobService.initialize());

  // Local stores and connectivity are independent: start them together.
  // Connectivity is capped — some devices answer slowly; we assume online
  // and the listener corrects it (offline scoring still works locally).
  final matchLocalStore = MatchLocalStore();
  final connectivityService = ConnectivityService();
  final prefsFuture = SharedPreferences.getInstance();
  await Future.wait<void>([
    matchLocalStore.init(),
    StartupTrace.capped<void>(
      connectivityService.init(),
      timeout: const Duration(milliseconds: 1500),
      fallback: null,
      label: 'connectivity',
    ),
    prefsFuture,
  ]);
  final prefs = await prefsFuture;
  StartupTrace.mark('local stores + connectivity + prefs');
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
