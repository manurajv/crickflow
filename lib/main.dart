import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/firebase_options.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'data/services/theme_service.dart';
import 'shared/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseBootstrap.configure();

  final prefs = await SharedPreferences.getInstance();
  final themeService = ThemeService(prefs: prefs);
  final initialThemeMode = themeService.readThemeMode(prefs);

  runApp(
    ProviderScope(
      overrides: [
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
