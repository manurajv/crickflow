/// Audit Center hub sections and classification enums.
enum AuditHubSection {
  dashboard,
  timeline,
  auditLogs,
  loginHistory,
  securityEvents,
  permissionChanges,
  dataChanges,
  systemEvents,
  exportCenter;

  String get label => switch (this) {
        AuditHubSection.dashboard => 'Dashboard',
        AuditHubSection.timeline => 'Activity Timeline',
        AuditHubSection.auditLogs => 'Audit Logs',
        AuditHubSection.loginHistory => 'Login History',
        AuditHubSection.securityEvents => 'Security Events',
        AuditHubSection.permissionChanges => 'Permission Changes',
        AuditHubSection.dataChanges => 'Data Changes',
        AuditHubSection.systemEvents => 'System Events',
        AuditHubSection.exportCenter => 'Export Center',
      };
}

enum AuditSeverity {
  info,
  warning,
  high,
  critical;

  String get label => switch (this) {
        AuditSeverity.info => 'Info',
        AuditSeverity.warning => 'Warning',
        AuditSeverity.high => 'High',
        AuditSeverity.critical => 'Critical',
      };

  String get wireValue => name;

  static AuditSeverity parse(String? raw) {
    if (raw == null || raw.isEmpty) return AuditSeverity.info;
    for (final s in AuditSeverity.values) {
      if (s.name == raw.toLowerCase()) return s;
    }
    return AuditSeverity.info;
  }
}

enum AuditStatus {
  success,
  failed,
  blocked,
  expired,
  pending;

  String get label => switch (this) {
        AuditStatus.success => 'Successful',
        AuditStatus.failed => 'Failed',
        AuditStatus.blocked => 'Blocked',
        AuditStatus.expired => 'Expired',
        AuditStatus.pending => 'Pending',
      };

  String get wireValue => name;

  static AuditStatus parse(String? raw) {
    if (raw == null || raw.isEmpty) return AuditStatus.success;
    for (final s in AuditStatus.values) {
      if (s.name == raw.toLowerCase()) return s;
    }
    return AuditStatus.success;
  }
}

enum AuditModule {
  users,
  organizations,
  teams,
  players,
  grounds,
  tournaments,
  matches,
  broadcasts,
  advertisements,
  community,
  discover,
  notifications,
  cms,
  settings,
  analytics,
  support,
  aiOps,
  auth,
  security,
  system,
  other;

  String get label => switch (this) {
        AuditModule.users => 'Users',
        AuditModule.organizations => 'Organizations',
        AuditModule.teams => 'Teams',
        AuditModule.players => 'Players',
        AuditModule.grounds => 'Grounds',
        AuditModule.tournaments => 'Tournaments',
        AuditModule.matches => 'Matches',
        AuditModule.broadcasts => 'Broadcasts',
        AuditModule.advertisements => 'Advertisements',
        AuditModule.community => 'Community',
        AuditModule.discover => 'Discover',
        AuditModule.notifications => 'Notifications',
        AuditModule.cms => 'CMS',
        AuditModule.settings => 'Settings',
        AuditModule.analytics => 'Analytics',
        AuditModule.support => 'Support',
        AuditModule.aiOps => 'AI Operations',
        AuditModule.auth => 'Auth',
        AuditModule.security => 'Security',
        AuditModule.system => 'System',
        AuditModule.other => 'Other',
      };

  String get wireValue => name;

  static AuditModule fromAction(String action) {
    final prefix = action.split('.').first.toLowerCase();
    return switch (prefix) {
      'user' => AuditModule.users,
      'organization' => AuditModule.organizations,
      'team' => AuditModule.teams,
      'player' => AuditModule.players,
      'ground' => AuditModule.grounds,
      'tournament' => AuditModule.tournaments,
      'match' => AuditModule.matches,
      'broadcast' => AuditModule.broadcasts,
      'ad' || 'advertiser' || 'admob' || 'sponsored' =>
        AuditModule.advertisements,
      'community' || 'report' => AuditModule.community,
      'discover' => AuditModule.discover,
      'notification' || 'announcement' || 'template' || 'segment' =>
        AuditModule.notifications,
      'cms' || 'legal' => AuditModule.cms,
      'settings' ||
      'feature_flag' ||
      'remote_config' ||
      'app_version' ||
      'maintenance' =>
        AuditModule.settings,
      'auth' => AuditModule.auth,
      'support' || 'ticket' => AuditModule.support,
      'ai' => AuditModule.aiOps,
      'security' => AuditModule.security,
      'devops' || 'deploy' || 'release' => AuditModule.system,
      'system' || 'firebase' || 'api' => AuditModule.system,
      _ => AuditModule.other,
    };
  }

  static AuditModule parse(String? raw, {String? action}) {
    if (raw != null && raw.isNotEmpty) {
      for (final m in AuditModule.values) {
        if (m.name == raw.toLowerCase() || m.wireValue == raw) return m;
      }
      // entity aliases from existing metadata
      switch (raw.toLowerCase()) {
        case 'organization':
          return AuditModule.organizations;
        case 'moderation':
          return AuditModule.community;
        case 'platform_settings':
        case 'feature_flag':
        case 'remote_config':
        case 'app_version':
        case 'maintenance':
        case 'cms_page':
        case 'legal_page':
          return AuditModule.settings;
        case 'tournament':
          return AuditModule.tournaments;
        case 'match':
          return AuditModule.matches;
        case 'team':
          return AuditModule.teams;
        case 'ground':
          return AuditModule.grounds;
        case 'broadcast':
          return AuditModule.broadcasts;
      }
    }
    if (action != null && action.isNotEmpty) return fromAction(action);
    return AuditModule.other;
  }
}

enum AuditRetentionPeriod {
  days30,
  days90,
  days180,
  year1,
  unlimited;

  String get label => switch (this) {
        AuditRetentionPeriod.days30 => '30 Days',
        AuditRetentionPeriod.days90 => '90 Days',
        AuditRetentionPeriod.days180 => '180 Days',
        AuditRetentionPeriod.year1 => '1 Year',
        AuditRetentionPeriod.unlimited => 'Unlimited',
      };
}

enum AuditExportFormat { csv, excel, pdf, json, backup }

extension AuditExportFormatLabel on AuditExportFormat {
  String get label => switch (this) {
        AuditExportFormat.csv => 'CSV',
        AuditExportFormat.excel => 'Excel',
        AuditExportFormat.pdf => 'PDF',
        AuditExportFormat.json => 'JSON',
        AuditExportFormat.backup => 'Audit Backup',
      };
}
