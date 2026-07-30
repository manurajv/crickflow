/// Hub sections for Analytics & Reports.
enum AnalyticsHubSection {
  overview,
  users,
  matches,
  tournaments,
  teams,
  players,
  streaming,
  community,
  advertisements,
  revenue,
  reports,
  exportCenter;

  String get label => switch (this) {
        AnalyticsHubSection.overview => 'Overview',
        AnalyticsHubSection.users => 'Users',
        AnalyticsHubSection.matches => 'Matches',
        AnalyticsHubSection.tournaments => 'Tournaments',
        AnalyticsHubSection.teams => 'Teams',
        AnalyticsHubSection.players => 'Players',
        AnalyticsHubSection.streaming => 'Streaming',
        AnalyticsHubSection.community => 'Community',
        AnalyticsHubSection.advertisements => 'Advertisements',
        AnalyticsHubSection.revenue => 'Revenue',
        AnalyticsHubSection.reports => 'Reports',
        AnalyticsHubSection.exportCenter => 'Export Center',
      };

  IconDataWire get iconKey => switch (this) {
        AnalyticsHubSection.overview => IconDataWire.dashboard,
        AnalyticsHubSection.users => IconDataWire.people,
        AnalyticsHubSection.matches => IconDataWire.sports,
        AnalyticsHubSection.tournaments => IconDataWire.trophy,
        AnalyticsHubSection.teams => IconDataWire.groups,
        AnalyticsHubSection.players => IconDataWire.person,
        AnalyticsHubSection.streaming => IconDataWire.liveTv,
        AnalyticsHubSection.community => IconDataWire.forum,
        AnalyticsHubSection.advertisements => IconDataWire.campaign,
        AnalyticsHubSection.revenue => IconDataWire.payments,
        AnalyticsHubSection.reports => IconDataWire.description,
        AnalyticsHubSection.exportCenter => IconDataWire.download,
      };
}

/// Lightweight icon keys so enums stay free of Flutter imports.
enum IconDataWire {
  dashboard,
  people,
  sports,
  trophy,
  groups,
  person,
  liveTv,
  forum,
  campaign,
  payments,
  description,
  download,
}

enum AnalyticsPeriod {
  daily,
  weekly,
  monthly,
  yearly,
  custom;

  String get label => switch (this) {
        AnalyticsPeriod.daily => 'Daily',
        AnalyticsPeriod.weekly => 'Weekly',
        AnalyticsPeriod.monthly => 'Monthly',
        AnalyticsPeriod.yearly => 'Yearly',
        AnalyticsPeriod.custom => 'Custom',
      };
}

enum AnalyticsExportFormat {
  csv,
  excel,
  pdf;

  String get label => switch (this) {
        AnalyticsExportFormat.csv => 'CSV',
        AnalyticsExportFormat.excel => 'Excel',
        AnalyticsExportFormat.pdf => 'PDF',
      };

  bool get supportedNow => this == AnalyticsExportFormat.csv;
}

enum AnalyticsReportKind {
  daily,
  weekly,
  monthly,
  yearly,
  custom;

  String get label => switch (this) {
        AnalyticsReportKind.daily => 'Daily Report',
        AnalyticsReportKind.weekly => 'Weekly Report',
        AnalyticsReportKind.monthly => 'Monthly Report',
        AnalyticsReportKind.yearly => 'Yearly Report',
        AnalyticsReportKind.custom => 'Custom Report',
      };
}
