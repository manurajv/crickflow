/// Business Continuity / Disaster Recovery hub sections and domain enums.
enum ContinuityHubSection {
  dashboard,
  firestoreBackup,
  storageBackup,
  configBackup,
  backupHistory,
  restoreCenter,
  recoveryPlans,
  disasterRecovery,
  migrationCenter,
  importCenter,
  exportCenter,
  healthVerification,
  timeline;

  String get label => switch (this) {
        ContinuityHubSection.dashboard => 'Backup Dashboard',
        ContinuityHubSection.firestoreBackup => 'Firestore Backup',
        ContinuityHubSection.storageBackup => 'Storage Backup',
        ContinuityHubSection.configBackup => 'Configuration Backup',
        ContinuityHubSection.backupHistory => 'Backup History',
        ContinuityHubSection.restoreCenter => 'Restore Center',
        ContinuityHubSection.recoveryPlans => 'Recovery Plans',
        ContinuityHubSection.disasterRecovery => 'Disaster Recovery',
        ContinuityHubSection.migrationCenter => 'Migration Center',
        ContinuityHubSection.importCenter => 'Import Center',
        ContinuityHubSection.exportCenter => 'Export Center',
        ContinuityHubSection.healthVerification => 'Health Verification',
        ContinuityHubSection.timeline => 'Continuity Timeline',
      };
}

enum ContinuityBackupType {
  firestore,
  storage,
  remoteConfig,
  platformSettings,
  cms,
  roles,
  permissions,
  featureFlags,
  appConfig,
  fullPlatform;

  String get label => switch (this) {
        ContinuityBackupType.firestore => 'Firestore',
        ContinuityBackupType.storage => 'Storage',
        ContinuityBackupType.remoteConfig => 'Remote Config',
        ContinuityBackupType.platformSettings => 'Platform Settings',
        ContinuityBackupType.cms => 'CMS',
        ContinuityBackupType.roles => 'Roles',
        ContinuityBackupType.permissions => 'Permissions',
        ContinuityBackupType.featureFlags => 'Feature Flags',
        ContinuityBackupType.appConfig => 'App Configuration',
        ContinuityBackupType.fullPlatform => 'Full Platform (metadata)',
      };

  String get wireValue => name;

  static ContinuityBackupType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityBackupType.firestore;
  }
}

enum ContinuityJobStatus {
  planned,
  queued,
  running,
  success,
  failed,
  cancelled,
  validating,
  awaitingConfirmation;

  String get label => switch (this) {
        ContinuityJobStatus.planned => 'Planned',
        ContinuityJobStatus.queued => 'Queued',
        ContinuityJobStatus.running => 'Running',
        ContinuityJobStatus.success => 'Success',
        ContinuityJobStatus.failed => 'Failed',
        ContinuityJobStatus.cancelled => 'Cancelled',
        ContinuityJobStatus.validating => 'Validating',
        ContinuityJobStatus.awaitingConfirmation => 'Awaiting confirmation',
      };

  String get wireValue => name;

  static ContinuityJobStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityJobStatus.planned;
  }
}

enum ContinuityFrequency {
  manual,
  daily,
  weekly,
  monthly,
  beforeDeployment,
  beforeMigration,
  beforeConfigChange;

  String get label => switch (this) {
        ContinuityFrequency.manual => 'Manual',
        ContinuityFrequency.daily => 'Daily',
        ContinuityFrequency.weekly => 'Weekly',
        ContinuityFrequency.monthly => 'Monthly',
        ContinuityFrequency.beforeDeployment => 'Before deployment',
        ContinuityFrequency.beforeMigration => 'Before migration',
        ContinuityFrequency.beforeConfigChange => 'Before config change',
      };

  String get wireValue => name;
}

enum ContinuityRestoreScope {
  entirePlatform,
  firestoreCollections,
  storage,
  configuration,
  settings,
  remoteConfig,
  cms,
  roles,
  permissions;

  String get label => switch (this) {
        ContinuityRestoreScope.entirePlatform => 'Entire platform',
        ContinuityRestoreScope.firestoreCollections => 'Firestore collections',
        ContinuityRestoreScope.storage => 'Storage',
        ContinuityRestoreScope.configuration => 'Configuration',
        ContinuityRestoreScope.settings => 'Settings',
        ContinuityRestoreScope.remoteConfig => 'Remote Config',
        ContinuityRestoreScope.cms => 'CMS',
        ContinuityRestoreScope.roles => 'Roles',
        ContinuityRestoreScope.permissions => 'Permissions',
      };

  String get wireValue => name;

  static ContinuityRestoreScope parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityRestoreScope.configuration;
  }
}

enum ContinuityPlanKind {
  platformFailure,
  firestoreCorruption,
  storageCorruption,
  hostingFailure,
  configurationFailure,
  deploymentFailure,
  accidentalDeletion,
  securityIncident;

  String get label => switch (this) {
        ContinuityPlanKind.platformFailure => 'Platform failure',
        ContinuityPlanKind.firestoreCorruption => 'Firestore corruption',
        ContinuityPlanKind.storageCorruption => 'Storage corruption',
        ContinuityPlanKind.hostingFailure => 'Hosting failure',
        ContinuityPlanKind.configurationFailure => 'Configuration failure',
        ContinuityPlanKind.deploymentFailure => 'Deployment failure',
        ContinuityPlanKind.accidentalDeletion => 'Accidental deletion',
        ContinuityPlanKind.securityIncident => 'Security incident',
      };

  String get wireValue => name;

  static ContinuityPlanKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityPlanKind.platformFailure;
  }
}

enum ContinuityMigrationKind {
  schema,
  collection,
  configuration,
  version,
  databaseFuture;

  String get label => switch (this) {
        ContinuityMigrationKind.schema => 'Schema migration',
        ContinuityMigrationKind.collection => 'Collection migration',
        ContinuityMigrationKind.configuration => 'Configuration migration',
        ContinuityMigrationKind.version => 'Version migration',
        ContinuityMigrationKind.databaseFuture => 'Database migration (future)',
      };

  String get wireValue => name;

  static ContinuityMigrationKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityMigrationKind.configuration;
  }
}

enum ContinuityHealthStatus {
  healthy,
  degraded,
  unknown,
  critical;

  String get label => switch (this) {
        ContinuityHealthStatus.healthy => 'Healthy',
        ContinuityHealthStatus.degraded => 'Degraded',
        ContinuityHealthStatus.unknown => 'Unknown',
        ContinuityHealthStatus.critical => 'Critical',
      };

  String get wireValue => name;

  static ContinuityHealthStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityHealthStatus.unknown;
  }
}

enum ContinuityTimelineKind {
  backupCreated,
  backupValidated,
  backupDeleted,
  restoreRequested,
  restoreCompleted,
  restoreRejected,
  migrationStarted,
  migrationCompleted,
  planUpdated,
  healthChecked,
  exportPrepared,
  importPrepared;

  String get label => switch (this) {
        ContinuityTimelineKind.backupCreated => 'Backup created',
        ContinuityTimelineKind.backupValidated => 'Backup validated',
        ContinuityTimelineKind.backupDeleted => 'Backup deleted',
        ContinuityTimelineKind.restoreRequested => 'Restore requested',
        ContinuityTimelineKind.restoreCompleted => 'Restore completed',
        ContinuityTimelineKind.restoreRejected => 'Restore rejected',
        ContinuityTimelineKind.migrationStarted => 'Migration started',
        ContinuityTimelineKind.migrationCompleted => 'Migration completed',
        ContinuityTimelineKind.planUpdated => 'Recovery plan updated',
        ContinuityTimelineKind.healthChecked => 'Health verification',
        ContinuityTimelineKind.exportPrepared => 'Export prepared',
        ContinuityTimelineKind.importPrepared => 'Import prepared',
      };

  String get wireValue => name;

  static ContinuityTimelineKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return ContinuityTimelineKind.backupCreated;
  }
}
