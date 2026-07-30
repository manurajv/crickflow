/// Security Operations Center hub sections and domain enums.
enum SocHubSection {
  dashboard,
  accessControl,
  roleManagement,
  permissionManagement,
  loginSessions,
  activeDevices,
  securityAlerts,
  threatDetection,
  blockLists,
  ipManagement,
  apiSecurity,
  backupCenter,
  restoreCenter,
  disasterRecovery,
  securityPolicies,
  compliance;

  String get label => switch (this) {
        SocHubSection.dashboard => 'Security Dashboard',
        SocHubSection.accessControl => 'Access Control',
        SocHubSection.roleManagement => 'Role Management',
        SocHubSection.permissionManagement => 'Permission Management',
        SocHubSection.loginSessions => 'Login Sessions',
        SocHubSection.activeDevices => 'Active Devices',
        SocHubSection.securityAlerts => 'Security Alerts',
        SocHubSection.threatDetection => 'Threat Detection',
        SocHubSection.blockLists => 'Block Lists',
        SocHubSection.ipManagement => 'IP Management',
        SocHubSection.apiSecurity => 'API Security',
        SocHubSection.backupCenter => 'Backup Center',
        SocHubSection.restoreCenter => 'Restore Center',
        SocHubSection.disasterRecovery => 'Disaster Recovery',
        SocHubSection.securityPolicies => 'Security Policies',
        SocHubSection.compliance => 'Compliance',
      };

  /// Platform-wide SOC tools — Super Admin only (unscoped data / DR architecture).
  bool get isPlatformOnly => switch (this) {
        SocHubSection.roleManagement ||
        SocHubSection.permissionManagement ||
        SocHubSection.ipManagement ||
        SocHubSection.apiSecurity ||
        SocHubSection.backupCenter ||
        SocHubSection.restoreCenter ||
        SocHubSection.disasterRecovery ||
        SocHubSection.securityPolicies ||
        SocHubSection.compliance =>
          true,
        _ => false,
      };

  static List<SocHubSection> visibleFor({required bool isSuperAdmin}) =>
      values.where((s) => isSuperAdmin || !s.isPlatformOnly).toList();
}

enum SocSeverity {
  info,
  warning,
  high,
  critical;

  String get label => switch (this) {
        SocSeverity.info => 'Info',
        SocSeverity.warning => 'Warning',
        SocSeverity.high => 'High',
        SocSeverity.critical => 'Critical',
      };

  String get wireValue => name;

  static SocSeverity parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocSeverity.info;
  }
}

enum SocAlertStatus {
  open,
  acknowledged,
  resolved,
  dismissed;

  String get label => switch (this) {
        SocAlertStatus.open => 'Open',
        SocAlertStatus.acknowledged => 'Acknowledged',
        SocAlertStatus.resolved => 'Resolved',
        SocAlertStatus.dismissed => 'Dismissed',
      };

  String get wireValue => name;

  static SocAlertStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocAlertStatus.open;
  }
}

enum SocBlockKind {
  user,
  device,
  email,
  ip,
  domain;

  String get label => switch (this) {
        SocBlockKind.user => 'User',
        SocBlockKind.device => 'Device',
        SocBlockKind.email => 'Email',
        SocBlockKind.ip => 'IP Address',
        SocBlockKind.domain => 'Domain',
      };

  String get wireValue => name;

  static SocBlockKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocBlockKind.user;
  }
}

enum SocBlockDuration {
  temporary,
  permanent;

  String get label => switch (this) {
        SocBlockDuration.temporary => 'Temporary',
        SocBlockDuration.permanent => 'Permanent',
      };

  String get wireValue => name;

  static SocBlockDuration parse(String? raw) {
    if (raw == 'temporary') return SocBlockDuration.temporary;
    return SocBlockDuration.permanent;
  }
}

enum SocIpListType {
  whitelist,
  blacklist,
  allowedCountry,
  restrictedCountry;

  String get label => switch (this) {
        SocIpListType.whitelist => 'Whitelist',
        SocIpListType.blacklist => 'Blacklist',
        SocIpListType.allowedCountry => 'Allowed Countries',
        SocIpListType.restrictedCountry => 'Restricted Countries',
      };

  String get wireValue => name;

  static SocIpListType parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocIpListType.blacklist;
  }
}

enum SocAccessKind {
  administrator,
  organization,
  module,
  temporary,
  readOnly,
  emergency;

  String get label => switch (this) {
        SocAccessKind.administrator => 'Administrator Access',
        SocAccessKind.organization => 'Organization Access',
        SocAccessKind.module => 'Module Access',
        SocAccessKind.temporary => 'Temporary Access',
        SocAccessKind.readOnly => 'Read Only Access',
        SocAccessKind.emergency => 'Emergency Access',
      };

  String get wireValue => name;

  static SocAccessKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocAccessKind.temporary;
  }
}

enum SocBackupKind {
  database,
  storage,
  configuration,
  remoteConfig,
  settings;

  String get label => switch (this) {
        SocBackupKind.database => 'Database Backup',
        SocBackupKind.storage => 'Storage Backup',
        SocBackupKind.configuration => 'Configuration Backup',
        SocBackupKind.remoteConfig => 'Remote Config Backup',
        SocBackupKind.settings => 'Settings Backup',
      };

  String get wireValue => name;

  static SocBackupKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocBackupKind.configuration;
  }
}

enum SocBackupStatus {
  planned,
  scheduled,
  completed,
  failed,
  validating;

  String get label => switch (this) {
        SocBackupStatus.planned => 'Planned',
        SocBackupStatus.scheduled => 'Scheduled',
        SocBackupStatus.completed => 'Completed',
        SocBackupStatus.failed => 'Failed',
        SocBackupStatus.validating => 'Validating',
      };

  String get wireValue => name;

  static SocBackupStatus parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocBackupStatus.planned;
  }
}

enum SocThreatKind {
  bruteForce,
  botActivity,
  spam,
  credentialStuffing,
  accountTakeover,
  other;

  String get label => switch (this) {
        SocThreatKind.bruteForce => 'Brute Force',
        SocThreatKind.botActivity => 'Bot Activity',
        SocThreatKind.spam => 'Spam',
        SocThreatKind.credentialStuffing => 'Credential Stuffing',
        SocThreatKind.accountTakeover => 'Account Takeover',
        SocThreatKind.other => 'Other',
      };

  String get wireValue => name;

  static SocThreatKind parse(String? raw) {
    for (final v in values) {
      if (v.name == raw) return v;
    }
    return SocThreatKind.other;
  }
}

/// Future-facing granular permission types for the matrix UI.
/// Current roles still use [AdminPermission] wire flags.
enum SocPermissionAction {
  view,
  create,
  edit,
  delete,
  approve,
  archive,
  restore,
  export,
  assign,
  feature,
  verify,
  suspend;

  String get label => switch (this) {
        SocPermissionAction.view => 'View',
        SocPermissionAction.create => 'Create',
        SocPermissionAction.edit => 'Edit',
        SocPermissionAction.delete => 'Delete',
        SocPermissionAction.approve => 'Approve',
        SocPermissionAction.archive => 'Archive',
        SocPermissionAction.restore => 'Restore',
        SocPermissionAction.export => 'Export',
        SocPermissionAction.assign => 'Assign',
        SocPermissionAction.feature => 'Feature',
        SocPermissionAction.verify => 'Verify',
        SocPermissionAction.suspend => 'Suspend',
      };
}

enum SocPermissionModule {
  users,
  organizations,
  teams,
  players,
  grounds,
  matches,
  tournaments,
  broadcasts,
  community,
  discover,
  notifications,
  advertisements,
  analytics,
  cms,
  settings,
  support,
  audit,
  ai,
  security,
  future;

  String get label => switch (this) {
        SocPermissionModule.users => 'Users',
        SocPermissionModule.organizations => 'Organizations',
        SocPermissionModule.teams => 'Teams',
        SocPermissionModule.players => 'Players',
        SocPermissionModule.grounds => 'Grounds',
        SocPermissionModule.matches => 'Matches',
        SocPermissionModule.tournaments => 'Tournaments',
        SocPermissionModule.broadcasts => 'Broadcasts',
        SocPermissionModule.community => 'Community',
        SocPermissionModule.discover => 'Discover',
        SocPermissionModule.notifications => 'Notifications',
        SocPermissionModule.advertisements => 'Advertisements',
        SocPermissionModule.analytics => 'Analytics',
        SocPermissionModule.cms => 'CMS',
        SocPermissionModule.settings => 'Settings',
        SocPermissionModule.support => 'Support',
        SocPermissionModule.audit => 'Audit',
        SocPermissionModule.ai => 'AI',
        SocPermissionModule.security => 'Security',
        SocPermissionModule.future => 'Future modules',
      };
}

enum SocRoleRecordStatus {
  active,
  archived;

  String get wireValue => name;

  static SocRoleRecordStatus parse(String? raw) {
    if (raw == 'archived') return SocRoleRecordStatus.archived;
    return SocRoleRecordStatus.active;
  }
}
