import 'package:equatable/equatable.dart';

class MatchInfoRow extends Equatable {
  const MatchInfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
    this.openDirectionsInMaps = false,
    this.route,
  });

  final String label;
  final String value;
  final bool highlight;
  final bool openDirectionsInMaps;
  /// In-app route (e.g. tournament dashboard) when the row is tappable.
  final String? route;

  @override
  List<Object?> get props => [label, value, openDirectionsInMaps, route];
}

class MatchInfoOfficial extends Equatable {
  const MatchInfoOfficial({
    required this.name,
    required this.role,
    this.playerId,
    this.photoUrl,
  });

  final String name;
  final String role;
  final String? playerId;
  final String? photoUrl;

  @override
  List<Object?> get props => [name, role, playerId];
}

class MatchInfoTimelineEntry extends Equatable {
  const MatchInfoTimelineEntry({
    required this.title,
    this.subtitle = '',
    this.timestamp,
    this.isAdminEvent = false,
  });

  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final bool isAdminEvent;

  @override
  List<Object?> get props => [title, subtitle, timestamp, isAdminEvent];
}

class MatchInfoQuickLink extends Equatable {
  const MatchInfoQuickLink({
    required this.label,
    required this.route,
    this.iconName = 'link',
  });

  final String label;
  final String route;
  final String iconName;

  @override
  List<Object?> get props => [label, route];
}

class MatchInfoDlsSection extends Equatable {
  const MatchInfoDlsSection({
    required this.title,
    required this.rows,
  });

  final String title;
  final List<MatchInfoRow> rows;

  @override
  List<Object?> get props => [title, rows];
}

class MatchInfoAbandonedSection extends Equatable {
  const MatchInfoAbandonedSection({
    required this.reason,
    this.timeLabel = '',
    this.resultStatus = '',
  });

  final String reason;
  final String timeLabel;
  final String resultStatus;

  @override
  List<Object?> get props => [reason, timeLabel, resultStatus];
}

class MatchInfoPenalty extends Equatable {
  const MatchInfoPenalty({
    required this.teamName,
    required this.runs,
    required this.reason,
    this.timestamp,
  });

  final String teamName;
  final int runs;
  final String reason;
  final DateTime? timestamp;

  @override
  List<Object?> get props => [teamName, runs, reason];
}

class MatchInfoSnapshot extends Equatable {
  const MatchInfoSnapshot({
    this.overview = const [],
    this.configuration = const [],
    this.officials = const [],
    this.notes = const [],
    this.adminEvents = const [],
    this.quickLinks = const [],
    this.conditions = const [],
    this.dlsSections = const [],
    this.penalties = const [],
    this.abandoned,
  });

  static const empty = MatchInfoSnapshot();

  final List<MatchInfoRow> overview;
  final List<MatchInfoRow> configuration;
  final List<MatchInfoOfficial> officials;
  final List<MatchInfoTimelineEntry> notes;
  final List<MatchInfoTimelineEntry> adminEvents;
  final List<MatchInfoQuickLink> quickLinks;
  final List<MatchInfoRow> conditions;
  final List<MatchInfoDlsSection> dlsSections;
  final List<MatchInfoPenalty> penalties;
  final MatchInfoAbandonedSection? abandoned;

  bool get hasOverview => overview.isNotEmpty;
  bool get hasConfiguration => configuration.isNotEmpty;
  bool get hasOfficials => officials.isNotEmpty;
  bool get hasNotes => notes.isNotEmpty;
  bool get hasAdminEvents => adminEvents.isNotEmpty;
  bool get hasQuickLinks => quickLinks.isNotEmpty;
  bool get hasConditions => conditions.isNotEmpty;
  bool get hasDls => dlsSections.isNotEmpty;
  bool get hasPenalties => penalties.isNotEmpty;

  @override
  List<Object?> get props => [
        overview,
        configuration,
        officials,
        notes,
        adminEvents,
        quickLinks,
        conditions,
        dlsSections,
        penalties,
        abandoned,
      ];
}
