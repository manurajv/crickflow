import 'package:intl/intl.dart';

import '../../matches/models/match_enums.dart';
import '../../moderation/models/moderation_enums.dart';
import '../../users/models/managed_user.dart';
import '../models/dashboard_models.dart';

/// Formats a Firestore [count] for dashboard tiles.
String formatDashboardCount(int n) {
  if (n < 0) return '—';
  if (n >= 1000000) {
    return NumberFormat.compact(locale: 'en').format(n);
  }
  return NumberFormat.decimalPattern('en').format(n);
}

String relativeDashboardTime(DateTime at, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(at);
  if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(at);
}

DateTime? parseDashboardDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  if (raw is String && raw.isNotEmpty) {
    return DateTime.tryParse(raw)?.toLocal();
  }
  try {
    // Firestore Timestamp (avoid a hard import here so tests stay pure).
    final method = raw.toDate;
    if (method is Function) {
      final dt = method() as DateTime;
      return dt.toLocal();
    }
  } catch (_) {}
  return null;
}

bool matchIsLive(String? status) {
  final parsed = ManagedMatchStatus.parse(status);
  return parsed == ManagedMatchStatus.live ||
      parsed == ManagedMatchStatus.inningsBreak;
}

String matchScoreLine(Map<String, dynamic> map) {
  final live = map['live'];
  if (live is Map) {
    final runs = live['runs'];
    final wickets = live['wickets'];
    if (runs != null) return '$runs/${wickets ?? 0}';
  }
  final score = map['score'] as String?;
  if (score != null && score.trim().isNotEmpty) return score.trim();
  return '—';
}

RecentMatchItem recentMatchFromMap(String id, Map<String, dynamic> map) {
  final status = ManagedMatchStatus.parse(map['status'] as String?);
  final teamA = (map['teamAName'] as String?)?.trim() ?? '';
  final teamB = (map['teamBName'] as String?)?.trim() ?? '';
  final title = (map['title'] as String?)?.trim();
  return RecentMatchItem(
    id: id,
    title: (title != null && title.isNotEmpty)
        ? title
        : '${teamA.isEmpty ? 'Team A' : teamA} vs ${teamB.isEmpty ? 'Team B' : teamB}',
    teamA: teamA.isEmpty ? 'Team A' : teamA,
    teamB: teamB.isEmpty ? 'Team B' : teamB,
    status: status.label,
    score: matchScoreLine(map),
    isLive: matchIsLive(map['status'] as String?),
  );
}

RecentUserItem recentUserFromMap(String id, Map<String, dynamic> map, {DateTime? now}) {
  final user = ManagedUser.fromFirestore(id: id, map: map);
  final joined = user.createdAt ?? parseDashboardDate(map['createdAt']);
  return RecentUserItem(
    id: id,
    name: user.effectiveName,
    country: user.country.isEmpty ? '—' : user.country,
    joinedLabel: joined == null ? '—' : relativeDashboardTime(joined, now: now),
    status: user.accountStatus.label,
    photoUrl: user.photoUrl,
  );
}

RecentTournamentItem recentTournamentFromMap(String id, Map<String, dynamic> map) {
  final title = (map['name'] as String?)?.trim().isNotEmpty == true
      ? (map['name'] as String).trim()
      : ((map['title'] as String?)?.trim() ?? 'Untitled tournament');
  final organizer = (map['organizerName'] as String?)?.trim() ??
      (map['createdByName'] as String?)?.trim() ??
      (map['hostName'] as String?)?.trim() ??
      '—';
  final status = (map['status'] as String?)?.trim();
  final label = (status == null || status.isEmpty)
      ? '—'
      : '${status[0].toUpperCase()}${status.substring(1)}';
  return RecentTournamentItem(
    id: id,
    title: title,
    organizer: organizer.isEmpty ? '—' : organizer,
    status: label,
    posterUrl: (map['posterUrl'] as String?) ?? (map['coverImageUrl'] as String?),
  );
}

RecentReportItem recentReportFromMap(String id, Map<String, dynamic> map) {
  final status = ManagedReportStatus.parse(map['status'] as String?);
  final reason = (map['reason'] as String?)?.trim();
  final name = (map['reporterName'] as String?)?.trim() ??
      (map['reporterUserId'] as String?)?.trim() ??
      'Unknown';
  return RecentReportItem(
    id: id,
    userName: name.isEmpty ? 'Unknown' : name,
    reason: (reason == null || reason.isEmpty) ? 'Reported content' : reason,
    status: status.label,
  );
}

ActivityItem? activityFromUser(String id, Map<String, dynamic> map) {
  final at = parseDashboardDate(map['createdAt']);
  if (at == null) return null;
  final user = ManagedUser.fromFirestore(id: id, map: map);
  return ActivityItem(
    id: 'user_$id',
    kind: ActivityKind.userRegistered,
    title: 'New user registered',
    subtitle: user.effectiveName,
    occurredAt: at,
  );
}

ActivityItem? activityFromMatch(String id, Map<String, dynamic> map) {
  final status = ManagedMatchStatus.parse(map['status'] as String?);
  final live = matchIsLive(map['status'] as String?);
  final at = parseDashboardDate(map['updatedAt']) ??
      parseDashboardDate(map['startedAt']) ??
      parseDashboardDate(map['createdAt']);
  if (at == null) return null;
  final item = recentMatchFromMap(id, map);
  if (live) {
    return ActivityItem(
      id: 'match_$id',
      kind: ActivityKind.matchStarted,
      title: 'Match live',
      subtitle: item.title,
      occurredAt: at,
    );
  }
  if (status == ManagedMatchStatus.completed ||
      status == ManagedMatchStatus.abandoned) {
    return ActivityItem(
      id: 'match_$id',
      kind: ActivityKind.matchCompleted,
      title: 'Match completed',
      subtitle: item.title,
      occurredAt: at,
    );
  }
  return ActivityItem(
    id: 'match_$id',
    kind: ActivityKind.matchStarted,
    title: 'Match updated',
    subtitle: item.title,
    occurredAt: at,
  );
}

ActivityItem? activityFromTournament(String id, Map<String, dynamic> map) {
  final at = parseDashboardDate(map['createdAt']);
  if (at == null) return null;
  final item = recentTournamentFromMap(id, map);
  return ActivityItem(
    id: 'tournament_$id',
    kind: ActivityKind.tournamentCreated,
    title: 'Tournament created',
    subtitle: item.title,
    occurredAt: at,
  );
}

ActivityItem? activityFromCommunityPost(String id, Map<String, dynamic> map) {
  final at = parseDashboardDate(map['createdAt']);
  if (at == null) return null;
  final text = (map['content'] as String?)?.trim() ??
      (map['text'] as String?)?.trim() ??
      (map['title'] as String?)?.trim() ??
      'Community post';
  return ActivityItem(
    id: 'post_$id',
    kind: ActivityKind.communityPost,
    title: 'Community post',
    subtitle: text.length > 80 ? '${text.substring(0, 80)}…' : text,
    occurredAt: at,
  );
}

ActivityItem? activityFromReport(String id, Map<String, dynamic> map) {
  final at = parseDashboardDate(map['createdAt']) ??
      parseDashboardDate(map['reportedAt']);
  if (at == null) return null;
  final item = recentReportFromMap(id, map);
  return ActivityItem(
    id: 'report_$id',
    kind: ActivityKind.reportSubmitted,
    title: 'Report submitted',
    subtitle: item.reason,
    occurredAt: at,
  );
}
