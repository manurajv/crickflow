/// DevOps & Release Center hub sections and domain enums.
enum DevOpsHubSection {
  dashboard,
  environments,
  releases,
  versionHistory,
  buildMonitor,
  featureRollout,
  rollbackCenter,
  deploymentLogs,
  envVariables,
  domains,
  releaseNotes,
  timeline,
  qualityGates;

  String get label => switch (this) {
        DevOpsHubSection.dashboard => 'Deployment Dashboard',
        DevOpsHubSection.environments => 'Environment Manager',
        DevOpsHubSection.releases => 'Release Management',
        DevOpsHubSection.versionHistory => 'Version History',
        DevOpsHubSection.buildMonitor => 'Build Monitor',
        DevOpsHubSection.featureRollout => 'Feature Rollout',
        DevOpsHubSection.rollbackCenter => 'Rollback Center',
        DevOpsHubSection.deploymentLogs => 'Deployment Logs',
        DevOpsHubSection.envVariables => 'Environment Variables',
        DevOpsHubSection.domains => 'Domain Management',
        DevOpsHubSection.releaseNotes => 'Release Notes',
        DevOpsHubSection.timeline => 'Deployment Timeline',
        DevOpsHubSection.qualityGates => 'Quality Gates',
      };
}

enum DevOpsEnvironment {
  development,
  testing,
  staging,
  production;

  String get label => switch (this) {
        DevOpsEnvironment.development => 'Development',
        DevOpsEnvironment.testing => 'Testing',
        DevOpsEnvironment.staging => 'Staging',
        DevOpsEnvironment.production => 'Production',
      };

  String get wireValue => name;

  static DevOpsEnvironment parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsEnvironment.development;
  }
}

enum DevOpsReleaseType {
  hotfix,
  patch,
  minor,
  major;

  String get label => switch (this) {
        DevOpsReleaseType.hotfix => 'Hotfix',
        DevOpsReleaseType.patch => 'Patch',
        DevOpsReleaseType.minor => 'Minor',
        DevOpsReleaseType.major => 'Major',
      };

  String get wireValue => name;

  static DevOpsReleaseType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsReleaseType.patch;
  }
}

enum DevOpsReleaseStatus {
  draft,
  scheduled,
  published,
  cancelled,
  archived;

  String get label => switch (this) {
        DevOpsReleaseStatus.draft => 'Draft',
        DevOpsReleaseStatus.scheduled => 'Scheduled',
        DevOpsReleaseStatus.published => 'Published',
        DevOpsReleaseStatus.cancelled => 'Cancelled',
        DevOpsReleaseStatus.archived => 'Archived',
      };

  String get wireValue => name;

  static DevOpsReleaseStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsReleaseStatus.draft;
  }
}

enum DevOpsDeployStatus {
  queued,
  started,
  success,
  failed,
  cancelled,
  completed;

  String get label => switch (this) {
        DevOpsDeployStatus.queued => 'Queued',
        DevOpsDeployStatus.started => 'Started',
        DevOpsDeployStatus.success => 'Success',
        DevOpsDeployStatus.failed => 'Failed',
        DevOpsDeployStatus.cancelled => 'Cancelled',
        DevOpsDeployStatus.completed => 'Completed',
      };

  String get wireValue => name;

  static DevOpsDeployStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsDeployStatus.queued;
  }
}

enum DevOpsBuildStatus {
  queued,
  running,
  success,
  failed,
  cancelled;

  String get label => switch (this) {
        DevOpsBuildStatus.queued => 'Queued',
        DevOpsBuildStatus.running => 'Running',
        DevOpsBuildStatus.success => 'Success',
        DevOpsBuildStatus.failed => 'Failed',
        DevOpsBuildStatus.cancelled => 'Cancelled',
      };

  String get wireValue => name;

  static DevOpsBuildStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsBuildStatus.queued;
  }
}

enum DevOpsRolloutPercent {
  internal,
  p5,
  p10,
  p25,
  p50,
  p100;

  String get label => switch (this) {
        DevOpsRolloutPercent.internal => 'Internal',
        DevOpsRolloutPercent.p5 => '5%',
        DevOpsRolloutPercent.p10 => '10%',
        DevOpsRolloutPercent.p25 => '25%',
        DevOpsRolloutPercent.p50 => '50%',
        DevOpsRolloutPercent.p100 => '100%',
      };

  String get wireValue => name;

  int get percent => switch (this) {
        DevOpsRolloutPercent.internal => 0,
        DevOpsRolloutPercent.p5 => 5,
        DevOpsRolloutPercent.p10 => 10,
        DevOpsRolloutPercent.p25 => 25,
        DevOpsRolloutPercent.p50 => 50,
        DevOpsRolloutPercent.p100 => 100,
      };

  static DevOpsRolloutPercent parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsRolloutPercent.internal;
  }
}

enum DevOpsRolloutStatus {
  planned,
  active,
  paused,
  rolledBack,
  completed;

  String get label => switch (this) {
        DevOpsRolloutStatus.planned => 'Planned',
        DevOpsRolloutStatus.active => 'Active',
        DevOpsRolloutStatus.paused => 'Paused',
        DevOpsRolloutStatus.rolledBack => 'Rolled Back',
        DevOpsRolloutStatus.completed => 'Completed',
      };

  String get wireValue => name;

  static DevOpsRolloutStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsRolloutStatus.planned;
  }
}

enum DevOpsDomainStatus {
  healthy,
  pending,
  error,
  unknown;

  String get label => switch (this) {
        DevOpsDomainStatus.healthy => 'Healthy',
        DevOpsDomainStatus.pending => 'Pending',
        DevOpsDomainStatus.error => 'Error',
        DevOpsDomainStatus.unknown => 'Unknown',
      };

  String get wireValue => name;

  static DevOpsDomainStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsDomainStatus.unknown;
  }
}

enum DevOpsTimelineKind {
  versionCreated,
  releasePublished,
  rollback,
  environmentUpdated,
  featureEnabled,
  maintenanceStarted,
  maintenanceEnded,
  deployment,
  other;

  String get label => switch (this) {
        DevOpsTimelineKind.versionCreated => 'Version Created',
        DevOpsTimelineKind.releasePublished => 'Release Published',
        DevOpsTimelineKind.rollback => 'Rollback',
        DevOpsTimelineKind.environmentUpdated => 'Environment Updated',
        DevOpsTimelineKind.featureEnabled => 'Feature Enabled',
        DevOpsTimelineKind.maintenanceStarted => 'Maintenance Started',
        DevOpsTimelineKind.maintenanceEnded => 'Maintenance Ended',
        DevOpsTimelineKind.deployment => 'Deployment',
        DevOpsTimelineKind.other => 'Other',
      };

  String get wireValue => name;

  static DevOpsTimelineKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return DevOpsTimelineKind.other;
  }
}
