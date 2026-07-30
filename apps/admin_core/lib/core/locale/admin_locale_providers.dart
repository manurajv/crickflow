import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../features/auth/providers/auth_providers.dart';
import '../../services/session_preferences.dart';
import 'admin_locale_catalog.dart';
import 'admin_regional_settings.dart';

/// Persisted regional + locale preferences for the admin panel.
final adminRegionalSettingsProvider =
    StateNotifierProvider<AdminRegionalController, AdminRegionalSettings>((ref) {
  return AdminRegionalController(ref.watch(sessionPreferencesProvider));
});

/// Effective [Locale] for MaterialApp (null language → follow device).
final adminLocaleProvider = Provider<Locale?>((ref) {
  final code = ref.watch(adminRegionalSettingsProvider).languageCode;
  return AdminLocaleCatalog.tryParse(code);
});

class AdminRegionalController extends StateNotifier<AdminRegionalSettings> {
  AdminRegionalController(this._prefs) : super(AdminRegionalSettings.defaults) {
    _load();
  }

  final SessionPreferences _prefs;
  bool _ready = false;

  bool get isReady => _ready;

  Future<void> _load() async {
    final loaded = await _prefs.getRegionalSettings();
    state = loaded;
    _ready = true;
  }

  Future<void> setLanguageCode(String? code) async {
    state = code == null || code == 'system'
        ? state.copyWith(clearLanguage: true)
        : state.copyWith(languageCode: code);
    await _prefs.saveRegionalSettings(state);
  }

  Future<void> update(AdminRegionalSettings next) async {
    state = next;
    await _prefs.saveRegionalSettings(state);
  }

  Future<void> setTimeZoneMode(AdminTimeZoneMode mode) async {
    state = state.copyWith(timeZoneMode: mode);
    await _prefs.saveRegionalSettings(state);
  }

  Future<void> setDateFormat(AdminDateFormatStyle style) async {
    state = state.copyWith(dateFormat: style);
    await _prefs.saveRegionalSettings(state);
  }

  Future<void> setTimeFormat(AdminTimeFormat format) async {
    state = state.copyWith(timeFormat: format);
    await _prefs.saveRegionalSettings(state);
  }

  Future<void> setPreferredTimeZone(String? ianaId) async {
    state = ianaId == null || ianaId.isEmpty
        ? state.copyWith(clearPreferredTz: true)
        : state.copyWith(preferredTimeZoneId: ianaId);
    await _prefs.saveRegionalSettings(state);
  }
}

/// Locale-aware date / time / number formatting for admin UI.
///
/// Does **not** change stored Firestore timestamps (always UTC Instant).
class AdminFormatters {
  AdminFormatters({
    required this.locale,
    required this.settings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Locale locale;
  final AdminRegionalSettings settings;
  final DateTime Function() _now;

  String get _localeName {
    final n = settings.numberLocaleCode;
    if (n != null && n.isNotEmpty) return n;
    if (settings.countryCode != null && settings.countryCode!.isNotEmpty) {
      return '${locale.languageCode}_${settings.countryCode}';
    }
    return locale.toString();
  }

  /// Convert a UTC or local [DateTime] for display according to timezone mode.
  DateTime displayInstant(DateTime value) {
    final utc = value.isUtc ? value : value.toUtc();
    switch (settings.timeZoneMode) {
      case AdminTimeZoneMode.utc:
        return utc;
      case AdminTimeZoneMode.browser:
        return utc.toLocal();
      case AdminTimeZoneMode.preferred:
      case AdminTimeZoneMode.organization:
        // IANA conversion without extra deps: fall back to local.
        // Architecture stores preferred / org TZ ids for future timezone package.
        return utc.toLocal();
    }
  }

  String formatDate(DateTime? value) {
    if (value == null) return '—';
    final d = displayInstant(value);
    final pattern = switch (settings.dateFormat) {
      AdminDateFormatStyle.medium => 'd MMM y',
      AdminDateFormatStyle.shortNumeric => 'dd/MM/y',
      AdminDateFormatStyle.iso => 'y-MM-dd',
      AdminDateFormatStyle.long => 'MMMM d, y',
    };
    return DateFormat(pattern, _localeName).format(d);
  }

  String formatTime(DateTime? value) {
    if (value == null) return '—';
    final d = displayInstant(value);
    final pattern =
        settings.timeFormat == AdminTimeFormat.h12 ? 'h:mm a' : 'HH:mm';
    return DateFormat(pattern, _localeName).format(d);
  }

  String formatDateTime(DateTime? value) {
    if (value == null) return '—';
    return '${formatDate(value)} ${formatTime(value)}';
  }

  String formatNumber(num? value, {int? decimalDigits}) {
    if (value == null) return '—';
    return NumberFormat.decimalPatternDigits(
      locale: _localeName,
      decimalDigits: decimalDigits,
    ).format(value);
  }

  String formatCompact(num? value) {
    if (value == null) return '—';
    return NumberFormat.compact(locale: _localeName).format(value);
  }

  String formatPercent(num? value, {int decimalDigits = 0}) {
    if (value == null) return '—';
    return NumberFormat.percentPattern(_localeName)
        .format(value is int ? value / 100 : value);
  }

  DateTime get nowDisplayed => displayInstant(_now().toUtc());
}

final adminFormattersProvider = Provider<AdminFormatters>((ref) {
  final settings = ref.watch(adminRegionalSettingsProvider);
  final overrideLocale = ref.watch(adminLocaleProvider);
  final locale = overrideLocale ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return AdminFormatters(locale: locale, settings: settings);
});
