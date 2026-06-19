import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/theme_service.dart';

final themeServiceProvider = Provider<ThemeService>((ref) => ThemeService());

/// Notifier for global theme control. Initial value is set before [runApp]
/// to avoid a visible flicker on cold start.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._service, ThemeMode initial) : super(initial);

  final ThemeService _service;

  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    await _service.saveThemeMode(mode);
  }

  Future<void> toggleLightDark() async {
    await setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(
    ref.watch(themeServiceProvider),
    ThemeMode.light,
  );
});
