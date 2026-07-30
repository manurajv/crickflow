import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/admin_collections.dart';
import '../../../models/admin_user.dart';
import '../../users/models/admin_audit_log.dart';
import '../models/platform_settings.dart';
import '../models/settings_enums.dart';

/// Platform Settings & CMS repository (admin-native collections only).
///
/// Never writes mobile Privacy/Terms URL fields, OAuth secrets, or Firebase
/// project configuration. Secrets are always masked in API status views.
class SettingsRepository {
  SettingsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const _globalDocId = 'global';
  static const _maintenanceDocId = 'current';

  CollectionReference<Map<String, dynamic>> get _settings =>
      _db.collection(AdminCollections.adminPlatformSettings);
  CollectionReference<Map<String, dynamic>> get _flags =>
      _db.collection(AdminCollections.adminFeatureFlags);
  CollectionReference<Map<String, dynamic>> get _remote =>
      _db.collection(AdminCollections.adminRemoteConfig);
  CollectionReference<Map<String, dynamic>> get _versions =>
      _db.collection(AdminCollections.adminAppVersions);
  CollectionReference<Map<String, dynamic>> get _maintenance =>
      _db.collection(AdminCollections.adminMaintenance);
  CollectionReference<Map<String, dynamic>> get _cms =>
      _db.collection(AdminCollections.adminCmsPages);
  CollectionReference<Map<String, dynamic>> get _legal =>
      _db.collection(AdminCollections.adminLegalPages);
  CollectionReference<Map<String, dynamic>> get _audit =>
      _db.collection(AdminCollections.adminAuditLogs);

  // ─── Snapshot ─────────────────────────────────────────────────────────────

  Future<SettingsHubSnapshot> fetchHubSnapshot() async {
    final results = await Future.wait([
      _fetchSettings(),
      _fetchFeatureFlags(),
      _fetchRemoteConfig(),
      _fetchVersions(),
      _fetchMaintenance(),
      _fetchCmsPages(),
      _fetchLegalPages(),
    ]);

    final settings = results[0] as PlatformSettingsDocument;
    final flags = results[1] as List<ManagedFeatureFlag>;
    final remote = results[2] as List<ManagedRemoteConfigEntry>;
    final versions = results[3] as List<ManagedAppVersion>;
    final maintenance = results[4] as MaintenanceConfig;
    final cms = results[5] as List<ManagedCmsPage>;
    final legal = results[6] as List<ManagedLegalPage>;

    final apiStatuses = _defaultApiStatuses();
    final firebaseStatuses = _defaultFirebaseStatuses();
    final dashboard = _buildDashboard(
      settings: settings,
      flags: flags,
      versions: versions,
      maintenance: maintenance,
      apiStatuses: apiStatuses,
    );

    return SettingsHubSnapshot(
      settings: settings,
      featureFlags: flags,
      remoteConfig: remote,
      versions: versions,
      maintenance: maintenance,
      cmsPages: cms,
      legalPages: legal,
      apiStatuses: apiStatuses,
      firebaseStatuses: firebaseStatuses,
      dashboard: dashboard,
    );
  }

  SettingsDashboardSnapshot _buildDashboard({
    required PlatformSettingsDocument settings,
    required List<ManagedFeatureFlag> flags,
    required List<ManagedAppVersion> versions,
    required MaintenanceConfig maintenance,
    required List<ApiServiceStatus> apiStatuses,
  }) {
    String latest(AppPlatform p) {
      final list = versions.where(
        (v) =>
            v.isCurrent &&
            (v.platform == p || v.platform == AppPlatform.both),
      );
      if (list.isEmpty) {
        final any = versions.where(
          (v) => v.platform == p || v.platform == AppPlatform.both,
        );
        return any.isEmpty ? '—' : any.first.latestVersion;
      }
      return list.first.latestVersion;
    }

    String minimum(AppPlatform p) {
      final list = versions.where(
        (v) =>
            v.isCurrent &&
            (v.platform == p || v.platform == AppPlatform.both),
      );
      if (list.isEmpty) return '—';
      return list.first.minimumVersion;
    }

    return SettingsDashboardSnapshot(
      androidLatest: latest(AppPlatform.android),
      iosLatest: latest(AppPlatform.ios),
      androidMinimum: minimum(AppPlatform.android),
      iosMinimum: minimum(AppPlatform.ios),
      maintenanceEnabled: maintenance.enabled,
      featureFlagsEnabled: flags.where((f) => f.enabled).length,
      featureFlagsTotal: flags.isEmpty
          ? FeatureFlagKey.values.length
          : flags.length,
      activeApis: apiStatuses
          .where(
            (a) =>
                a.status == ServiceHealthStatus.enabled ||
                a.status == ServiceHealthStatus.healthy,
          )
          .length,
      lastSettingsUpdate: settings.updatedAt,
      environment: settings.environment,
    );
  }

  // ─── Settings CRUD ────────────────────────────────────────────────────────

  Future<PlatformSettingsDocument> _fetchSettings() async {
    try {
      final doc = await _settings.doc(_globalDocId).get();
      return PlatformSettingsDocument.fromFirestore(doc.data());
    } catch (_) {
      return const PlatformSettingsDocument();
    }
  }

  Future<void> saveSettings({
    required PlatformSettingsDocument draft,
    required AdminUser actor,
    String? reason,
    String section = 'general',
  }) async {
    final previous = await _fetchSettings();
    await _settings.doc(_globalDocId).set(
          draft.toMap(updatedBy: actor.uid),
          SetOptions(merge: true),
        );
    await _writeAudit(
      action: AdminAuditActions.settingsUpdated,
      actor: actor,
      reason: reason,
      metadata: {
        'section': section,
        'entity': 'platform_settings',
      },
      oldValue: previous.updatedAt?.toIso8601String(),
      newValue: DateTime.now().toIso8601String(),
    );
  }

  // ─── Feature flags ────────────────────────────────────────────────────────

  Future<List<ManagedFeatureFlag>> _fetchFeatureFlags() async {
    try {
      final snap = await _flags.limit(50).get();
      if (snap.docs.isEmpty) {
        return FeatureFlagKey.values
            .map(
              (k) => ManagedFeatureFlag(
                id: k.wireValue,
                key: k.wireValue,
                label: k.label,
                description: k.description,
                enabled: false,
              ),
            )
            .toList();
      }
      final byKey = <String, ManagedFeatureFlag>{};
      for (final d in snap.docs) {
        final f = ManagedFeatureFlag.fromFirestore(id: d.id, map: d.data());
        byKey[f.key] = f;
      }
      // Ensure all known keys exist in UI.
      return FeatureFlagKey.values.map((k) {
        return byKey[k.wireValue] ??
            ManagedFeatureFlag(
              id: k.wireValue,
              key: k.wireValue,
              label: k.label,
              description: k.description,
            );
      }).toList();
    } catch (_) {
      return FeatureFlagKey.values
          .map(
            (k) => ManagedFeatureFlag(
              id: k.wireValue,
              key: k.wireValue,
              label: k.label,
              description: k.description,
            ),
          )
          .toList();
    }
  }

  Future<void> setFeatureFlag({
    required FeatureFlagKey key,
    required bool enabled,
    required AdminUser actor,
    String? reason,
  }) async {
    final ref = _flags.doc(key.wireValue);
    await ref.set({
      'key': key.wireValue,
      'label': key.label,
      'description': key.description,
      'enabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: enabled
          ? AdminAuditActions.featureFlagEnabled
          : AdminAuditActions.featureFlagDisabled,
      actor: actor,
      reason: reason,
      metadata: {'flag': key.wireValue, 'entity': 'feature_flag'},
      oldValue: (!enabled).toString(),
      newValue: enabled.toString(),
    );
  }

  // ─── Remote config ────────────────────────────────────────────────────────

  Future<List<ManagedRemoteConfigEntry>> _fetchRemoteConfig() async {
    try {
      final snap = await _remote.orderBy('key').limit(100).get();
      if (snap.docs.isEmpty) return _defaultRemoteConfigEntries();
      return snap.docs
          .map(
            (d) =>
                ManagedRemoteConfigEntry.fromFirestore(id: d.id, map: d.data()),
          )
          .toList();
    } catch (_) {
      try {
        final snap = await _remote.limit(100).get();
        if (snap.docs.isEmpty) return _defaultRemoteConfigEntries();
        return snap.docs
            .map(
              (d) => ManagedRemoteConfigEntry.fromFirestore(
                id: d.id,
                map: d.data(),
              ),
            )
            .toList();
      } catch (_) {
        return _defaultRemoteConfigEntries();
      }
    }
  }

  List<ManagedRemoteConfigEntry> _defaultRemoteConfigEntries() {
    const defaults = <(String, String, String, RemoteConfigValueType)>[
      ('maxUploadSizeMb', '25', 'Maximum upload size (MB)', RemoteConfigValueType.number),
      ('defaultMatchRadiusKm', '25', 'Default match radius (km)', RemoteConfigValueType.number),
      ('maxTeamMembers', '15', 'Maximum team members', RemoteConfigValueType.number),
      ('defaultStreamResolution', '720p', 'Default stream resolution', RemoteConfigValueType.string),
      ('defaultStreamBitrate', '2500', 'Default stream bitrate (kbps)', RemoteConfigValueType.number),
      ('communityPostLimit', '50', 'Community posts page limit', RemoteConfigValueType.number),
      ('discoverPostLimit', '50', 'Discover posts page limit', RemoteConfigValueType.number),
      ('notificationDailyLimit', '20', 'Notification daily limit', RemoteConfigValueType.number),
    ];
    return [
      for (final d in defaults)
        ManagedRemoteConfigEntry(
          id: d.$1,
          key: d.$1,
          value: d.$2,
          description: d.$3,
          valueType: d.$4,
        ),
    ];
  }

  Future<void> upsertRemoteConfig({
    required ManagedRemoteConfigEntry entry,
    required AdminUser actor,
    String? reason,
  }) async {
    final id = entry.id.isEmpty ? entry.key.trim() : entry.id;
    if (id.isEmpty) throw ArgumentError('Config key is required');
    await _remote.doc(id).set(
          entry.toMap(updatedBy: actor.uid),
          SetOptions(merge: true),
        );
    await _writeAudit(
      action: AdminAuditActions.remoteConfigUpdated,
      actor: actor,
      reason: reason,
      metadata: {'key': entry.key, 'entity': 'remote_config'},
      newValue: entry.value,
    );
  }

  Future<void> deleteRemoteConfig({
    required String id,
    required AdminUser actor,
    String? reason,
  }) async {
    await _remote.doc(id).delete();
    await _writeAudit(
      action: AdminAuditActions.remoteConfigDeleted,
      actor: actor,
      reason: reason,
      metadata: {'key': id, 'entity': 'remote_config'},
    );
  }

  Future<void> setRemoteConfigEnabled({
    required String id,
    required bool enabled,
    required AdminUser actor,
    String? reason,
  }) async {
    await _remote.doc(id).set({
      'enabled': enabled,
      'updatedAt': DateTime.now().toIso8601String(),
      'updatedBy': actor.uid,
    }, SetOptions(merge: true));
    await _writeAudit(
      action: AdminAuditActions.remoteConfigUpdated,
      actor: actor,
      reason: reason,
      metadata: {
        'key': id,
        'enabled': enabled,
        'entity': 'remote_config',
      },
    );
  }

  // ─── App versions ─────────────────────────────────────────────────────────

  Future<List<ManagedAppVersion>> _fetchVersions() async {
    try {
      final snap = await _versions
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();
      return snap.docs
          .map((d) => ManagedAppVersion.fromFirestore(id: d.id, map: d.data()))
          .toList();
    } catch (_) {
      try {
        final snap = await _versions.limit(50).get();
        return snap.docs
            .map(
              (d) => ManagedAppVersion.fromFirestore(id: d.id, map: d.data()),
            )
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> createAppVersion({
    required ManagedAppVersion draft,
    required AdminUser actor,
    String? reason,
  }) async {
    final batch = _db.batch();
    if (draft.isCurrent) {
      final existing = await _versions
          .where('isCurrent', isEqualTo: true)
          .where('platform', isEqualTo: draft.platform.name)
          .limit(20)
          .get();
      for (final d in existing.docs) {
        batch.set(d.reference, {'isCurrent': false}, SetOptions(merge: true));
      }
    }
    final ref = _versions.doc();
    batch.set(ref, draft.toMap(createdBy: actor.uid));
    await batch.commit();
    await _writeAudit(
      action: AdminAuditActions.appVersionUpdated,
      actor: actor,
      reason: reason,
      metadata: {
        'platform': draft.platform.name,
        'version': draft.latestVersion,
        'entity': 'app_version',
      },
      newValue: draft.latestVersion,
    );
  }

  // ─── Maintenance ──────────────────────────────────────────────────────────

  Future<MaintenanceConfig> _fetchMaintenance() async {
    try {
      final doc = await _maintenance.doc(_maintenanceDocId).get();
      return MaintenanceConfig.fromFirestore(doc.data());
    } catch (_) {
      return const MaintenanceConfig();
    }
  }

  Future<void> saveMaintenance({
    required MaintenanceConfig config,
    required AdminUser actor,
    String? reason,
  }) async {
    final previous = await _fetchMaintenance();
    await _maintenance.doc(_maintenanceDocId).set(
          config.toMap(updatedBy: actor.uid),
          SetOptions(merge: true),
        );
    final action = config.enabled && !previous.enabled
        ? AdminAuditActions.maintenanceStarted
        : (!config.enabled && previous.enabled
            ? AdminAuditActions.maintenanceEnded
            : AdminAuditActions.maintenanceUpdated);
    await _writeAudit(
      action: action,
      actor: actor,
      reason: reason,
      metadata: {
        'enabled': config.enabled,
        'entity': 'maintenance',
      },
      oldValue: previous.enabled.toString(),
      newValue: config.enabled.toString(),
    );
  }

  // ─── CMS ──────────────────────────────────────────────────────────────────

  Future<List<ManagedCmsPage>> _fetchCmsPages() async {
    try {
      final snap = await _cms.limit(30).get();
      final byKind = <CmsPageKind, ManagedCmsPage>{};
      for (final d in snap.docs) {
        final p = ManagedCmsPage.fromFirestore(id: d.id, map: d.data());
        byKind[p.kind] = p;
      }
      return CmsPageKind.values
          .map(
            (k) =>
                byKind[k] ??
                ManagedCmsPage(id: k.wireValue, kind: k, title: k.label),
          )
          .toList();
    } catch (_) {
      return CmsPageKind.values
          .map(
            (k) => ManagedCmsPage(id: k.wireValue, kind: k, title: k.label),
          )
          .toList();
    }
  }

  Future<void> saveCmsPage({
    required ManagedCmsPage page,
    required AdminUser actor,
    String? reason,
  }) async {
    await _cms.doc(page.kind.wireValue).set(
          page.toMap(updatedBy: actor.uid),
          SetOptions(merge: true),
        );
    await _writeAudit(
      action: AdminAuditActions.cmsPageUpdated,
      actor: actor,
      reason: reason,
      metadata: {'kind': page.kind.wireValue, 'entity': 'cms_page'},
      newValue: page.title,
    );
  }

  // ─── Legal (content only — never URLs) ─────────────────────────────────────

  Future<List<ManagedLegalPage>> _fetchLegalPages() async {
    try {
      final snap = await _legal.limit(20).get();
      final byKind = <LegalPageKind, ManagedLegalPage>{};
      for (final d in snap.docs) {
        final p = ManagedLegalPage.fromFirestore(id: d.id, map: d.data());
        byKind[p.kind] = p;
      }
      return LegalPageKind.values
          .map(
            (k) =>
                byKind[k] ??
                ManagedLegalPage(
                  id: k.wireValue,
                  kind: k,
                  title: k.label,
                  existingUrlNote: k.urlLocked
                      ? 'Existing public URL is locked and is never modified by this module.'
                      : '',
                ),
          )
          .toList();
    } catch (_) {
      return LegalPageKind.values
          .map(
            (k) => ManagedLegalPage(
              id: k.wireValue,
              kind: k,
              title: k.label,
              existingUrlNote: k.urlLocked
                  ? 'Existing public URL is locked and is never modified by this module.'
                  : '',
            ),
          )
          .toList();
    }
  }

  Future<void> saveLegalPage({
    required ManagedLegalPage page,
    required AdminUser actor,
    String? reason,
  }) async {
    // Explicitly omit any `url` field — existing Privacy/Terms URLs stay intact.
    await _legal.doc(page.kind.wireValue).set(
          page.toMap(updatedBy: actor.uid),
          SetOptions(merge: true),
        );
    await _writeAudit(
      action: AdminAuditActions.legalPageUpdated,
      actor: actor,
      reason: reason,
      metadata: {
        'kind': page.kind.wireValue,
        'entity': 'legal_page',
        'urlLocked': page.kind.urlLocked,
      },
      newValue: page.title,
    );
  }

  // ─── Status stubs (no secrets) ────────────────────────────────────────────

  List<ApiServiceStatus> _defaultApiStatuses() => [
        for (final k in ApiServiceKind.values)
          ApiServiceStatus(
            kind: k,
            status: ServiceHealthStatus.healthy,
            maskedKey: '••••••••••••',
            note: 'Status mirror only — secrets never exposed',
          ),
      ];

  List<FirebaseServiceStatus> _defaultFirebaseStatuses() => [
        for (final k in FirebaseServiceKind.values)
          FirebaseServiceStatus(
            kind: k,
            status: ServiceHealthStatus.healthy,
            note: 'Read-only status — Firebase project config is never modified',
          ),
      ];

  // ─── Audit ────────────────────────────────────────────────────────────────

  Future<List<AdminAuditLogEntry>> fetchSettingsAudit({int limit = 40}) async {
    try {
      final snap = await _audit
          .where('metadata.entity', whereIn: [
            'platform_settings',
            'feature_flag',
            'remote_config',
            'app_version',
            'maintenance',
            'cms_page',
            'legal_page',
          ])
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
          .toList();
    } catch (_) {
      // Fallback: recent audits filtered client-side.
      try {
        final snap = await _audit
            .orderBy('timestamp', descending: true)
            .limit(80)
            .get();
        final entities = {
          'platform_settings',
          'feature_flag',
          'remote_config',
          'app_version',
          'maintenance',
          'cms_page',
          'legal_page',
        };
        return snap.docs
            .map((d) => AdminAuditLogEntry.fromMap(d.id, d.data()))
            .where((e) => entities.contains(e.metadata['entity']))
            .take(limit)
            .toList();
      } catch (_) {
        return const [];
      }
    }
  }

  Future<void> _writeAudit({
    required String action,
    required AdminUser actor,
    String? reason,
    Map<String, dynamic> metadata = const {},
    String? oldValue,
    String? newValue,
  }) async {
    final entry = AdminAuditLogEntry(
      id: '',
      action: action,
      actorUid: actor.uid,
      actorEmail: actor.email,
      targetUid: 'platform',
      targetEmail: 'platform_settings',
      timestamp: DateTime.now(),
      reason: reason,
      metadata: {
        ...metadata,
        if (oldValue != null) 'oldValue': oldValue,
        if (newValue != null) 'newValue': newValue,
      },
    );
    await _audit.add(entry.toMap());
  }
}
