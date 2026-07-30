import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'settings_enums.dart';

// ─── Platform settings (single doc) ───────────────────────────────────────────

class PlatformGeneralSettings extends Equatable {
  const PlatformGeneralSettings({
    this.appName = 'CrickFlow',
    this.appShortName = 'CrickFlow',
    this.companyName = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.website = '',
    this.copyright = '',
    this.timezone = 'UTC',
    this.defaultLanguage = 'en',
    this.country = '',
    this.currency = 'USD',
    this.dateFormat = 'dd MMM yyyy',
    this.timeFormat = 'HH:mm',
    this.logoUrl = '',
    this.appIconUrl = '',
    this.splashLogoUrl = '',
    this.faviconUrl = '',
  });

  final String appName;
  final String appShortName;
  final String companyName;
  final String supportEmail;
  final String supportPhone;
  final String website;
  final String copyright;
  final String timezone;
  final String defaultLanguage;
  final String country;
  final String currency;
  final String dateFormat;
  final String timeFormat;
  final String logoUrl;
  final String appIconUrl;
  final String splashLogoUrl;
  final String faviconUrl;

  factory PlatformGeneralSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlatformGeneralSettings();
    return PlatformGeneralSettings(
      appName: (map['appName'] as String?)?.trim() ?? 'CrickFlow',
      appShortName: (map['appShortName'] as String?)?.trim() ?? 'CrickFlow',
      companyName: (map['companyName'] as String?)?.trim() ?? '',
      supportEmail: (map['supportEmail'] as String?)?.trim() ?? '',
      supportPhone: (map['supportPhone'] as String?)?.trim() ?? '',
      website: (map['website'] as String?)?.trim() ?? '',
      copyright: (map['copyright'] as String?)?.trim() ?? '',
      timezone: (map['timezone'] as String?)?.trim() ?? 'UTC',
      defaultLanguage: (map['defaultLanguage'] as String?)?.trim() ?? 'en',
      country: (map['country'] as String?)?.trim() ?? '',
      currency: (map['currency'] as String?)?.trim() ?? 'USD',
      dateFormat: (map['dateFormat'] as String?)?.trim() ?? 'dd MMM yyyy',
      timeFormat: (map['timeFormat'] as String?)?.trim() ?? 'HH:mm',
      logoUrl: (map['logoUrl'] as String?)?.trim() ?? '',
      appIconUrl: (map['appIconUrl'] as String?)?.trim() ?? '',
      splashLogoUrl: (map['splashLogoUrl'] as String?)?.trim() ?? '',
      faviconUrl: (map['faviconUrl'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'appName': appName.trim(),
        'appShortName': appShortName.trim(),
        'companyName': companyName.trim(),
        'supportEmail': supportEmail.trim(),
        'supportPhone': supportPhone.trim(),
        'website': website.trim(),
        'copyright': copyright.trim(),
        'timezone': timezone.trim(),
        'defaultLanguage': defaultLanguage.trim(),
        'country': country.trim(),
        'currency': currency.trim(),
        'dateFormat': dateFormat.trim(),
        'timeFormat': timeFormat.trim(),
        'logoUrl': logoUrl.trim(),
        'appIconUrl': appIconUrl.trim(),
        'splashLogoUrl': splashLogoUrl.trim(),
        'faviconUrl': faviconUrl.trim(),
      };

  @override
  List<Object?> get props => [appName, supportEmail, updatedFingerprint];

  String get updatedFingerprint => '$appName|$supportEmail|$logoUrl';
}

class PlatformBrandingSettings extends Equatable {
  const PlatformBrandingSettings({
    this.primaryColor = '#1565C0',
    this.secondaryColor = '#00897B',
    this.accentColor = '#F9A825',
    this.darkPrimary = '#90CAF9',
    this.darkSecondary = '#80CBC4',
    this.darkAccent = '#FFD54F',
    this.lightPrimary = '#1565C0',
    this.lightSecondary = '#00897B',
    this.lightAccent = '#F9A825',
    this.placeholderImageUrl = '',
  });

  final String primaryColor;
  final String secondaryColor;
  final String accentColor;
  final String darkPrimary;
  final String darkSecondary;
  final String darkAccent;
  final String lightPrimary;
  final String lightSecondary;
  final String lightAccent;
  final String placeholderImageUrl;

  factory PlatformBrandingSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlatformBrandingSettings();
    return PlatformBrandingSettings(
      primaryColor: (map['primaryColor'] as String?) ?? '#1565C0',
      secondaryColor: (map['secondaryColor'] as String?) ?? '#00897B',
      accentColor: (map['accentColor'] as String?) ?? '#F9A825',
      darkPrimary: (map['darkPrimary'] as String?) ?? '#90CAF9',
      darkSecondary: (map['darkSecondary'] as String?) ?? '#80CBC4',
      darkAccent: (map['darkAccent'] as String?) ?? '#FFD54F',
      lightPrimary: (map['lightPrimary'] as String?) ?? '#1565C0',
      lightSecondary: (map['lightSecondary'] as String?) ?? '#00897B',
      lightAccent: (map['lightAccent'] as String?) ?? '#F9A825',
      placeholderImageUrl: (map['placeholderImageUrl'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentColor': accentColor,
        'darkPrimary': darkPrimary,
        'darkSecondary': darkSecondary,
        'darkAccent': darkAccent,
        'lightPrimary': lightPrimary,
        'lightSecondary': lightSecondary,
        'lightAccent': lightAccent,
        'placeholderImageUrl': placeholderImageUrl,
      };

  @override
  List<Object?> get props => [primaryColor, secondaryColor, accentColor];
}

class PlatformContactSettings extends Equatable {
  const PlatformContactSettings({
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.website = '',
    this.supportHours = '',
    this.emergencyContact = '',
  });

  final String email;
  final String phone;
  final String whatsapp;
  final String address;
  final String website;
  final String supportHours;
  final String emergencyContact;

  factory PlatformContactSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlatformContactSettings();
    return PlatformContactSettings(
      email: (map['email'] as String?)?.trim() ?? '',
      phone: (map['phone'] as String?)?.trim() ?? '',
      whatsapp: (map['whatsapp'] as String?)?.trim() ?? '',
      address: (map['address'] as String?)?.trim() ?? '',
      website: (map['website'] as String?)?.trim() ?? '',
      supportHours: (map['supportHours'] as String?)?.trim() ?? '',
      emergencyContact: (map['emergencyContact'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'email': email.trim(),
        'phone': phone.trim(),
        'whatsapp': whatsapp.trim(),
        'address': address.trim(),
        'website': website.trim(),
        'supportHours': supportHours.trim(),
        'emergencyContact': emergencyContact.trim(),
      };

  @override
  List<Object?> get props => [email, phone, website];
}

class PlatformSocialSettings extends Equatable {
  const PlatformSocialSettings({
    this.facebook = '',
    this.instagram = '',
    this.youtube = '',
    this.linkedin = '',
    this.x = '',
    this.tiktok = '',
    this.website = '',
  });

  final String facebook;
  final String instagram;
  final String youtube;
  final String linkedin;
  final String x;
  final String tiktok;
  final String website;

  factory PlatformSocialSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlatformSocialSettings();
    return PlatformSocialSettings(
      facebook: (map['facebook'] as String?)?.trim() ?? '',
      instagram: (map['instagram'] as String?)?.trim() ?? '',
      youtube: (map['youtube'] as String?)?.trim() ?? '',
      linkedin: (map['linkedin'] as String?)?.trim() ?? '',
      x: (map['x'] as String?)?.trim() ?? '',
      tiktok: (map['tiktok'] as String?)?.trim() ?? '',
      website: (map['website'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'facebook': facebook.trim(),
        'instagram': instagram.trim(),
        'youtube': youtube.trim(),
        'linkedin': linkedin.trim(),
        'x': x.trim(),
        'tiktok': tiktok.trim(),
        'website': website.trim(),
      };

  List<(String, String)> get entries => [
        ('Facebook', facebook),
        ('Instagram', instagram),
        ('YouTube', youtube),
        ('LinkedIn', linkedin),
        ('X', x),
        ('TikTok', tiktok),
        ('Website', website),
      ];

  @override
  List<Object?> get props => [facebook, instagram, youtube, x];
}

class PlatformSystemPrefs extends Equatable {
  const PlatformSystemPrefs({
    this.timezone = 'UTC',
    this.dateFormat = 'dd MMM yyyy',
    this.numberFormat = 'en_US',
    this.language = 'en',
    this.country = '',
    this.currency = 'USD',
  });

  final String timezone;
  final String dateFormat;
  final String numberFormat;
  final String language;
  final String country;
  final String currency;

  factory PlatformSystemPrefs.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlatformSystemPrefs();
    return PlatformSystemPrefs(
      timezone: (map['timezone'] as String?)?.trim() ?? 'UTC',
      dateFormat: (map['dateFormat'] as String?)?.trim() ?? 'dd MMM yyyy',
      numberFormat: (map['numberFormat'] as String?)?.trim() ?? 'en_US',
      language: (map['language'] as String?)?.trim() ?? 'en',
      country: (map['country'] as String?)?.trim() ?? '',
      currency: (map['currency'] as String?)?.trim() ?? 'USD',
    );
  }

  Map<String, dynamic> toMap() => {
        'timezone': timezone.trim(),
        'dateFormat': dateFormat.trim(),
        'numberFormat': numberFormat.trim(),
        'language': language.trim(),
        'country': country.trim(),
        'currency': currency.trim(),
      };

  @override
  List<Object?> get props => [timezone, language, currency];
}

/// Root document for platform settings (`admin_platform_settings/global`).
class PlatformSettingsDocument extends Equatable {
  const PlatformSettingsDocument({
    this.general = const PlatformGeneralSettings(),
    this.branding = const PlatformBrandingSettings(),
    this.contact = const PlatformContactSettings(),
    this.social = const PlatformSocialSettings(),
    this.systemPrefs = const PlatformSystemPrefs(),
    this.environment = PlatformEnvironment.production,
    this.updatedAt,
    this.updatedBy,
  });

  final PlatformGeneralSettings general;
  final PlatformBrandingSettings branding;
  final PlatformContactSettings contact;
  final PlatformSocialSettings social;
  final PlatformSystemPrefs systemPrefs;
  final PlatformEnvironment environment;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory PlatformSettingsDocument.fromFirestore(Map<String, dynamic>? map) {
    if (map == null) return const PlatformSettingsDocument();
    final envRaw = (map['environment'] as String?)?.toLowerCase();
    final env = PlatformEnvironment.values.firstWhere(
      (e) => e.name == envRaw,
      orElse: () => PlatformEnvironment.production,
    );
    return PlatformSettingsDocument(
      general: PlatformGeneralSettings.fromMap(
        map['general'] as Map<String, dynamic>?,
      ),
      branding: PlatformBrandingSettings.fromMap(
        map['branding'] as Map<String, dynamic>?,
      ),
      contact: PlatformContactSettings.fromMap(
        map['contact'] as Map<String, dynamic>?,
      ),
      social: PlatformSocialSettings.fromMap(
        map['social'] as Map<String, dynamic>?,
      ),
      systemPrefs: PlatformSystemPrefs.fromMap(
        map['systemPrefs'] as Map<String, dynamic>?,
      ),
      environment: env,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) {
    final now = DateTime.now().toIso8601String();
    return {
      'general': general.toMap(),
      'branding': branding.toMap(),
      'contact': contact.toMap(),
      'social': social.toMap(),
      'systemPrefs': systemPrefs.toMap(),
      'environment': environment.name,
      'updatedAt': now,
      'updatedBy': updatedBy,
    };
  }

  PlatformSettingsDocument copyWith({
    PlatformGeneralSettings? general,
    PlatformBrandingSettings? branding,
    PlatformContactSettings? contact,
    PlatformSocialSettings? social,
    PlatformSystemPrefs? systemPrefs,
    PlatformEnvironment? environment,
  }) {
    return PlatformSettingsDocument(
      general: general ?? this.general,
      branding: branding ?? this.branding,
      contact: contact ?? this.contact,
      social: social ?? this.social,
      systemPrefs: systemPrefs ?? this.systemPrefs,
      environment: environment ?? this.environment,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  @override
  List<Object?> get props => [general, branding, contact, updatedAt];
}

// ─── Feature flags ────────────────────────────────────────────────────────────

class ManagedFeatureFlag extends Equatable {
  const ManagedFeatureFlag({
    required this.id,
    required this.key,
    this.enabled = false,
    this.label = '',
    this.description = '',
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String key;
  final bool enabled;
  final String label;
  final String description;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ManagedFeatureFlag.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    return ManagedFeatureFlag(
      id: id,
      key: (map['key'] as String?) ?? id,
      enabled: (map['enabled'] as bool?) ?? false,
      label: (map['label'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) => {
        'key': key,
        'enabled': enabled,
        'label': label,
        'description': description,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
      };

  @override
  List<Object?> get props => [id, key, enabled];
}

// ─── Remote config ────────────────────────────────────────────────────────────

class ManagedRemoteConfigEntry extends Equatable {
  const ManagedRemoteConfigEntry({
    required this.id,
    required this.key,
    this.value = '',
    this.valueType = RemoteConfigValueType.string,
    this.description = '',
    this.enabled = true,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final String key;
  final String value;
  final RemoteConfigValueType valueType;
  final String description;
  final bool enabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ManagedRemoteConfigEntry.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final typeRaw = (map['valueType'] as String?) ?? 'string';
    final type = RemoteConfigValueType.values.firstWhere(
      (t) => t.name == typeRaw,
      orElse: () => RemoteConfigValueType.string,
    );
    return ManagedRemoteConfigEntry(
      id: id,
      key: (map['key'] as String?) ?? id,
      value: '${map['value'] ?? ''}',
      valueType: type,
      description: (map['description'] as String?) ?? '',
      enabled: (map['enabled'] as bool?) ?? true,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) => {
        'key': key.trim(),
        'value': value,
        'valueType': valueType.name,
        'description': description.trim(),
        'enabled': enabled,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
      };

  @override
  List<Object?> get props => [id, key, value, enabled];
}

// ─── App versions ─────────────────────────────────────────────────────────────

class ManagedAppVersion extends Equatable {
  const ManagedAppVersion({
    required this.id,
    this.platform = AppPlatform.both,
    this.latestVersion = '',
    this.minimumVersion = '',
    this.releaseNotes = '',
    this.updateType = VersionUpdateType.soft,
    this.releaseDate,
    this.isCurrent = false,
    this.createdAt,
    this.createdBy,
  });

  final String id;
  final AppPlatform platform;
  final String latestVersion;
  final String minimumVersion;
  final String releaseNotes;
  final VersionUpdateType updateType;
  final DateTime? releaseDate;
  final bool isCurrent;
  final DateTime? createdAt;
  final String? createdBy;

  factory ManagedAppVersion.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final platformRaw = (map['platform'] as String?) ?? 'both';
    final platform = AppPlatform.values.firstWhere(
      (p) => p.name == platformRaw,
      orElse: () => AppPlatform.both,
    );
    final updateRaw = (map['updateType'] as String?) ?? 'soft';
    final updateType = VersionUpdateType.values.firstWhere(
      (u) => u.name == updateRaw,
      orElse: () => VersionUpdateType.soft,
    );
    return ManagedAppVersion(
      id: id,
      platform: platform,
      latestVersion: (map['latestVersion'] as String?) ?? '',
      minimumVersion: (map['minimumVersion'] as String?) ?? '',
      releaseNotes: (map['releaseNotes'] as String?) ?? '',
      updateType: updateType,
      releaseDate: _parseDate(map['releaseDate']),
      isCurrent: (map['isCurrent'] as bool?) ?? false,
      createdAt: _parseDate(map['createdAt']),
      createdBy: map['createdBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String createdBy}) => {
        'platform': platform.name,
        'latestVersion': latestVersion.trim(),
        'minimumVersion': minimumVersion.trim(),
        'releaseNotes': releaseNotes.trim(),
        'updateType': updateType.name,
        'releaseDate':
            (releaseDate ?? DateTime.now()).toIso8601String(),
        'isCurrent': isCurrent,
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': createdBy,
      };

  @override
  List<Object?> get props => [id, platform, latestVersion, updateType];
}

// ─── Maintenance ──────────────────────────────────────────────────────────────

class MaintenanceConfig extends Equatable {
  const MaintenanceConfig({
    this.enabled = false,
    this.title = 'Under Maintenance',
    this.description =
        'CrickFlow is temporarily unavailable. Please check back soon.',
    this.estimatedCompletion,
    this.bypassRoles = const {MaintenanceBypassRole.superAdmin},
    this.updatedAt,
    this.updatedBy,
  });

  final bool enabled;
  final String title;
  final String description;
  final DateTime? estimatedCompletion;
  final Set<MaintenanceBypassRole> bypassRoles;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory MaintenanceConfig.fromFirestore(Map<String, dynamic>? map) {
    if (map == null) return const MaintenanceConfig();
    final rolesRaw = (map['bypassRoles'] as List?)?.cast<String>() ?? [];
    final roles = <MaintenanceBypassRole>{};
    for (final r in rolesRaw) {
      for (final role in MaintenanceBypassRole.values) {
        if (role.name == r) roles.add(role);
      }
    }
    if (roles.isEmpty) roles.add(MaintenanceBypassRole.superAdmin);
    return MaintenanceConfig(
      enabled: (map['enabled'] as bool?) ?? false,
      title: (map['title'] as String?) ?? 'Under Maintenance',
      description: (map['description'] as String?) ?? '',
      estimatedCompletion: _parseDate(map['estimatedCompletion']),
      bypassRoles: roles,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) => {
        'enabled': enabled,
        'title': title.trim(),
        'description': description.trim(),
        'estimatedCompletion': estimatedCompletion?.toIso8601String(),
        'bypassRoles': bypassRoles.map((r) => r.name).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
      };

  MaintenanceConfig copyWith({
    bool? enabled,
    String? title,
    String? description,
    DateTime? estimatedCompletion,
    Set<MaintenanceBypassRole>? bypassRoles,
    bool clearEta = false,
  }) {
    return MaintenanceConfig(
      enabled: enabled ?? this.enabled,
      title: title ?? this.title,
      description: description ?? this.description,
      estimatedCompletion:
          clearEta ? null : (estimatedCompletion ?? this.estimatedCompletion),
      bypassRoles: bypassRoles ?? this.bypassRoles,
      updatedAt: updatedAt,
      updatedBy: updatedBy,
    );
  }

  @override
  List<Object?> get props => [enabled, title, estimatedCompletion];
}

// ─── CMS / Legal pages ────────────────────────────────────────────────────────

class ManagedCmsPage extends Equatable {
  const ManagedCmsPage({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    this.published = false,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final CmsPageKind kind;
  final String title;
  final String body;
  final bool published;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ManagedCmsPage.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final kindRaw = (map['kind'] as String?) ?? id;
    final kind = CmsPageKind.values.firstWhere(
      (k) => k.wireValue == kindRaw,
      orElse: () => CmsPageKind.home,
    );
    return ManagedCmsPage(
      id: id,
      kind: kind,
      title: (map['title'] as String?) ?? kind.label,
      body: (map['body'] as String?) ?? '',
      published: (map['published'] as bool?) ?? false,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap({required String updatedBy}) => {
        'kind': kind.wireValue,
        'title': title.trim(),
        'body': body,
        'published': published,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
      };

  @override
  List<Object?> get props => [id, kind, title, published, updatedAt];
}

class ManagedLegalPage extends Equatable {
  const ManagedLegalPage({
    required this.id,
    required this.kind,
    this.title = '',
    this.body = '',
    /// Display-only reference to existing public URL — never written as source of truth.
    this.existingUrlNote = '',
    this.published = false,
    this.updatedAt,
    this.updatedBy,
  });

  final String id;
  final LegalPageKind kind;
  final String title;
  final String body;
  final String existingUrlNote;
  final bool published;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory ManagedLegalPage.fromFirestore({
    required String id,
    required Map<String, dynamic> map,
  }) {
    final kindRaw = (map['kind'] as String?) ?? id;
    final kind = LegalPageKind.values.firstWhere(
      (k) => k.wireValue == kindRaw,
      orElse: () => LegalPageKind.privacyPolicy,
    );
    return ManagedLegalPage(
      id: id,
      kind: kind,
      title: (map['title'] as String?) ?? kind.label,
      body: (map['body'] as String?) ?? '',
      existingUrlNote: (map['existingUrlNote'] as String?) ?? '',
      published: (map['published'] as bool?) ?? false,
      updatedAt: _parseDate(map['updatedAt']),
      updatedBy: map['updatedBy'] as String?,
    );
  }

  /// Never writes a `url` field — existing Privacy / Terms URLs stay untouched.
  Map<String, dynamic> toMap({required String updatedBy}) => {
        'kind': kind.wireValue,
        'title': title.trim(),
        'body': body,
        'existingUrlNote': existingUrlNote,
        'published': published,
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': updatedBy,
      };

  @override
  List<Object?> get props => [id, kind, title, published, updatedAt];
}

// ─── API / Firebase status (admin-mirror, secrets masked) ─────────────────────

class ApiServiceStatus extends Equatable {
  const ApiServiceStatus({
    required this.kind,
    this.status = ServiceHealthStatus.unknown,
    this.maskedKey = '••••••••',
    this.note = '',
  });

  final ApiServiceKind kind;
  final ServiceHealthStatus status;
  final String maskedKey;
  final String note;

  @override
  List<Object?> get props => [kind, status];
}

class FirebaseServiceStatus extends Equatable {
  const FirebaseServiceStatus({
    required this.kind,
    this.status = ServiceHealthStatus.unknown,
    this.note = '',
  });

  final FirebaseServiceKind kind;
  final ServiceHealthStatus status;
  final String note;

  @override
  List<Object?> get props => [kind, status];
}

// ─── Dashboard snapshot ───────────────────────────────────────────────────────

class SettingsDashboardSnapshot extends Equatable {
  const SettingsDashboardSnapshot({
    this.androidLatest = '—',
    this.iosLatest = '—',
    this.androidMinimum = '—',
    this.iosMinimum = '—',
    this.maintenanceEnabled = false,
    this.featureFlagsEnabled = 0,
    this.featureFlagsTotal = 0,
    this.activeApis = 0,
    this.lastSettingsUpdate,
    this.environment = PlatformEnvironment.production,
  });

  final String androidLatest;
  final String iosLatest;
  final String androidMinimum;
  final String iosMinimum;
  final bool maintenanceEnabled;
  final int featureFlagsEnabled;
  final int featureFlagsTotal;
  final int activeApis;
  final DateTime? lastSettingsUpdate;
  final PlatformEnvironment environment;

  @override
  List<Object?> get props => [
        androidLatest,
        maintenanceEnabled,
        featureFlagsEnabled,
        lastSettingsUpdate,
      ];
}

/// Full hub payload loaded once per refresh.
class SettingsHubSnapshot extends Equatable {
  const SettingsHubSnapshot({
    this.settings = const PlatformSettingsDocument(),
    this.featureFlags = const [],
    this.remoteConfig = const [],
    this.versions = const [],
    this.maintenance = const MaintenanceConfig(),
    this.cmsPages = const [],
    this.legalPages = const [],
    this.apiStatuses = const [],
    this.firebaseStatuses = const [],
    this.dashboard = const SettingsDashboardSnapshot(),
  });

  final PlatformSettingsDocument settings;
  final List<ManagedFeatureFlag> featureFlags;
  final List<ManagedRemoteConfigEntry> remoteConfig;
  final List<ManagedAppVersion> versions;
  final MaintenanceConfig maintenance;
  final List<ManagedCmsPage> cmsPages;
  final List<ManagedLegalPage> legalPages;
  final List<ApiServiceStatus> apiStatuses;
  final List<FirebaseServiceStatus> firebaseStatuses;
  final SettingsDashboardSnapshot dashboard;

  @override
  List<Object?> get props => [
        settings,
        featureFlags,
        remoteConfig,
        versions,
        maintenance,
        cmsPages,
        legalPages,
      ];
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}
