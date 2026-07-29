import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Snapshot for the admin landing dashboard.
///
/// Values are currently placeholder-friendly. Swap the repository later to
/// load real Firestore aggregates without changing presentation widgets.
class DashboardSnapshot extends Equatable {
  const DashboardSnapshot({
    required this.generatedAt,
    required this.scopeLabel,
    required this.isOrganizationScoped,
    required this.overview,
    required this.quickActions,
    required this.activity,
    required this.systemStatus,
    required this.platformHealth,
    required this.recentMatches,
    required this.recentReports,
    required this.recentUsers,
    required this.recentTournaments,
    required this.analyticsPlaceholders,
  });

  final DateTime generatedAt;
  final String scopeLabel;
  final bool isOrganizationScoped;
  final List<OverviewMetric> overview;
  final List<QuickActionItem> quickActions;
  final List<ActivityItem> activity;
  final List<SystemStatusItem> systemStatus;
  final List<HealthMetric> platformHealth;
  final List<RecentMatchItem> recentMatches;
  final List<RecentReportItem> recentReports;
  final List<RecentUserItem> recentUsers;
  final List<RecentTournamentItem> recentTournaments;
  final List<AnalyticsPlaceholderItem> analyticsPlaceholders;

  @override
  List<Object?> get props => [generatedAt, scopeLabel, overview.length];
}

class OverviewMetric extends Equatable {
  const OverviewMetric({
    required this.id,
    required this.title,
    required this.value,
    required this.growthLabel,
    required this.icon,
    required this.accent,
    this.growthPositive,
    this.sparkline = const [0.4, 0.55, 0.45, 0.7, 0.62, 0.8, 0.75],
  });

  final String id;
  final String title;
  final String value;
  final String growthLabel;
  final bool? growthPositive;
  final IconData icon;
  final Color accent;
  final List<double> sparkline;

  @override
  List<Object?> get props => [id, value, growthLabel];
}

class QuickActionItem extends Equatable {
  const QuickActionItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
    required this.accent,
  });

  final String id;
  final String label;
  final IconData icon;
  final String route;
  final Color accent;

  @override
  List<Object?> get props => [id, route];
}

enum ActivityKind {
  userRegistered,
  tournamentCreated,
  matchStarted,
  matchCompleted,
  streamStarted,
  streamEnded,
  communityPost,
  reportSubmitted,
}

class ActivityItem extends Equatable {
  const ActivityItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.occurredAt,
  });

  final String id;
  final ActivityKind kind;
  final String title;
  final String subtitle;
  final DateTime occurredAt;

  @override
  List<Object?> get props => [id, kind, occurredAt];
}

enum ServiceHealth { healthy, warning, offline }

class SystemStatusItem extends Equatable {
  const SystemStatusItem({
    required this.id,
    required this.name,
    required this.status,
    required this.detail,
  });

  final String id;
  final String name;
  final ServiceHealth status;
  final String detail;

  @override
  List<Object?> get props => [id, status, detail];
}

class HealthMetric extends Equatable {
  const HealthMetric({
    required this.id,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String id;
  final String label;
  final String value;
  final IconData icon;

  @override
  List<Object?> get props => [id, value];
}

class RecentMatchItem extends Equatable {
  const RecentMatchItem({
    required this.id,
    required this.title,
    required this.teamA,
    required this.teamB,
    required this.status,
    required this.score,
    required this.isLive,
  });

  final String id;
  final String title;
  final String teamA;
  final String teamB;
  final String status;
  final String score;
  final bool isLive;

  @override
  List<Object?> get props => [id, status, score, isLive];
}

class RecentReportItem extends Equatable {
  const RecentReportItem({
    required this.id,
    required this.userName,
    required this.reason,
    required this.status,
  });

  final String id;
  final String userName;
  final String reason;
  final String status;

  @override
  List<Object?> get props => [id, status];
}

class RecentUserItem extends Equatable {
  const RecentUserItem({
    required this.id,
    required this.name,
    required this.country,
    required this.joinedLabel,
    required this.status,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String country;
  final String joinedLabel;
  final String status;
  final String? photoUrl;

  @override
  List<Object?> get props => [id, status];
}

class RecentTournamentItem extends Equatable {
  const RecentTournamentItem({
    required this.id,
    required this.title,
    required this.organizer,
    required this.status,
    this.posterUrl,
  });

  final String id;
  final String title;
  final String organizer;
  final String status;
  final String? posterUrl;

  @override
  List<Object?> get props => [id, status];
}

class AnalyticsPlaceholderItem extends Equatable {
  const AnalyticsPlaceholderItem({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;

  @override
  List<Object?> get props => [id];
}
