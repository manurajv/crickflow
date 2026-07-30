/// System Operations Center hub sections.
enum MonitoringHubSection {
  overview,
  firebaseServices,
  liveStatus,
  firestore,
  authentication,
  cloudFunctions,
  storage,
  hosting,
  pushNotifications,
  liveStreaming,
  database,
  performance,
  errors,
  scheduledJobs,
  backgroundTasks,
  healthTimeline;

  String get label => switch (this) {
        MonitoringHubSection.overview => 'Overview',
        MonitoringHubSection.firebaseServices => 'Firebase Services',
        MonitoringHubSection.liveStatus => 'Live Status',
        MonitoringHubSection.firestore => 'Firestore',
        MonitoringHubSection.authentication => 'Authentication',
        MonitoringHubSection.cloudFunctions => 'Cloud Functions',
        MonitoringHubSection.storage => 'Storage',
        MonitoringHubSection.hosting => 'Hosting',
        MonitoringHubSection.pushNotifications => 'Push Notifications',
        MonitoringHubSection.liveStreaming => 'Live Streaming',
        MonitoringHubSection.database => 'Database',
        MonitoringHubSection.performance => 'Performance',
        MonitoringHubSection.errors => 'Error Monitoring',
        MonitoringHubSection.scheduledJobs => 'Scheduled Jobs',
        MonitoringHubSection.backgroundTasks => 'Background Tasks',
        MonitoringHubSection.healthTimeline => 'Health Timeline',
      };
}

enum PlatformServiceHealth {
  healthy,
  warning,
  offline,
  unknown,
  critical;

  String get label => switch (this) {
        PlatformServiceHealth.healthy => 'Healthy',
        PlatformServiceHealth.warning => 'Warning',
        PlatformServiceHealth.offline => 'Offline',
        PlatformServiceHealth.unknown => 'Unknown',
        PlatformServiceHealth.critical => 'Critical',
      };

  String get wireValue => name;
}

enum MonitoringSeverity {
  info,
  warning,
  high,
  critical;

  String get label => switch (this) {
        MonitoringSeverity.info => 'Info',
        MonitoringSeverity.warning => 'Warning',
        MonitoringSeverity.high => 'High',
        MonitoringSeverity.critical => 'Critical',
      };
}

enum MonitoringEnvironment { development, staging, production }

enum FirebaseServiceId {
  firestore,
  authentication,
  storage,
  hosting,
  cloudFunctions,
  messaging,
  analytics,
  remoteConfig,
  appCheck,
  performance;

  String get label => switch (this) {
        FirebaseServiceId.firestore => 'Firestore',
        FirebaseServiceId.authentication => 'Authentication',
        FirebaseServiceId.storage => 'Storage',
        FirebaseServiceId.hosting => 'Hosting',
        FirebaseServiceId.cloudFunctions => 'Cloud Functions',
        FirebaseServiceId.messaging => 'Cloud Messaging',
        FirebaseServiceId.analytics => 'Analytics',
        FirebaseServiceId.remoteConfig => 'Remote Config',
        FirebaseServiceId.appCheck => 'App Check',
        FirebaseServiceId.performance => 'Performance Monitoring',
      };
}

enum ScheduledJobKind {
  scheduledNotifications,
  automaticCleanup,
  databaseBackups,
  analyticsJobs,
  maintenanceJobs,
  leaderboardRecalculation,
  rankingUpdates,
  badgeCalculations;

  String get label => switch (this) {
        ScheduledJobKind.scheduledNotifications => 'Scheduled Notifications',
        ScheduledJobKind.automaticCleanup => 'Automatic Cleanup',
        ScheduledJobKind.databaseBackups => 'Database Backups',
        ScheduledJobKind.analyticsJobs => 'Analytics Jobs',
        ScheduledJobKind.maintenanceJobs => 'Maintenance Jobs',
        ScheduledJobKind.leaderboardRecalculation => 'Leaderboard Recalculation',
        ScheduledJobKind.rankingUpdates => 'Ranking Updates',
        ScheduledJobKind.badgeCalculations => 'Badge Calculations',
      };
}

enum BackgroundTaskStatus { running, completed, failed, pending }
