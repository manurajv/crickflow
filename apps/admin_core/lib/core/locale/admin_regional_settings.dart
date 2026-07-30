import 'package:equatable/equatable.dart';

/// User / organization regional preferences (UI only — never affects auth/ACL).
enum AdminTimeZoneMode {
  utc,
  browser,
  preferred,
  organization,
}

enum AdminTimeFormat {
  h12,
  h24,
}

enum AdminDateFormatStyle {
  /// e.g. 30 Jul 2026
  medium,
  /// e.g. 30/07/2026
  shortNumeric,
  /// e.g. 2026-07-30
  iso,
  /// e.g. July 30, 2026
  long,
}

class AdminRegionalSettings extends Equatable {
  const AdminRegionalSettings({
    this.languageCode,
    this.countryCode,
    this.timeZoneMode = AdminTimeZoneMode.browser,
    this.preferredTimeZoneId,
    this.organizationTimeZoneId,
    this.dateFormat = AdminDateFormatStyle.medium,
    this.timeFormat = AdminTimeFormat.h24,
    this.numberLocaleCode,
  });

  static const defaults = AdminRegionalSettings();

  /// Null = system / browser language for UI strings.
  final String? languageCode;

  /// ISO 3166-1 alpha-2 when known (formatting hints).
  final String? countryCode;

  final AdminTimeZoneMode timeZoneMode;
  final String? preferredTimeZoneId;
  final String? organizationTimeZoneId;
  final AdminDateFormatStyle dateFormat;
  final AdminTimeFormat timeFormat;

  /// Override for [NumberFormat] locale; null uses UI locale.
  final String? numberLocaleCode;

  AdminRegionalSettings copyWith({
    String? languageCode,
    bool clearLanguage = false,
    String? countryCode,
    bool clearCountry = false,
    AdminTimeZoneMode? timeZoneMode,
    String? preferredTimeZoneId,
    bool clearPreferredTz = false,
    String? organizationTimeZoneId,
    bool clearOrgTz = false,
    AdminDateFormatStyle? dateFormat,
    AdminTimeFormat? timeFormat,
    String? numberLocaleCode,
    bool clearNumberLocale = false,
  }) {
    return AdminRegionalSettings(
      languageCode: clearLanguage ? null : (languageCode ?? this.languageCode),
      countryCode: clearCountry ? null : (countryCode ?? this.countryCode),
      timeZoneMode: timeZoneMode ?? this.timeZoneMode,
      preferredTimeZoneId: clearPreferredTz
          ? null
          : (preferredTimeZoneId ?? this.preferredTimeZoneId),
      organizationTimeZoneId: clearOrgTz
          ? null
          : (organizationTimeZoneId ?? this.organizationTimeZoneId),
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      numberLocaleCode: clearNumberLocale
          ? null
          : (numberLocaleCode ?? this.numberLocaleCode),
    );
  }

  Map<String, String> toPrefsMap() => {
        'languageCode': ?languageCode,
        'countryCode': ?countryCode,
        'timeZoneMode': timeZoneMode.name,
        'preferredTimeZoneId': ?preferredTimeZoneId,
        'organizationTimeZoneId': ?organizationTimeZoneId,
        'dateFormat': dateFormat.name,
        'timeFormat': timeFormat.name,
        'numberLocaleCode': ?numberLocaleCode,
      };

  factory AdminRegionalSettings.fromPrefsMap(Map<String, String> map) {
    AdminTimeZoneMode tzMode = AdminTimeZoneMode.browser;
    for (final v in AdminTimeZoneMode.values) {
      if (v.name == map['timeZoneMode']) tzMode = v;
    }
    AdminDateFormatStyle date = AdminDateFormatStyle.medium;
    for (final v in AdminDateFormatStyle.values) {
      if (v.name == map['dateFormat']) date = v;
    }
    AdminTimeFormat time = AdminTimeFormat.h24;
    for (final v in AdminTimeFormat.values) {
      if (v.name == map['timeFormat']) time = v;
    }
    return AdminRegionalSettings(
      languageCode: map['languageCode'],
      countryCode: map['countryCode'],
      timeZoneMode: tzMode,
      preferredTimeZoneId: map['preferredTimeZoneId'],
      organizationTimeZoneId: map['organizationTimeZoneId'],
      dateFormat: date,
      timeFormat: time,
      numberLocaleCode: map['numberLocaleCode'],
    );
  }

  @override
  List<Object?> get props => [
        languageCode,
        countryCode,
        timeZoneMode,
        preferredTimeZoneId,
        organizationTimeZoneId,
        dateFormat,
        timeFormat,
        numberLocaleCode,
      ];
}
