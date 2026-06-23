import '../../data/models/match_model.dart';
import '../../data/models/tournament/tournament_activity_model.dart';
import '../../data/models/tournament/tournament_group_model.dart';
import '../../data/models/tournament/tournament_official_model.dart';
import '../../data/models/tournament/tournament_sponsor_model.dart';
import '../../data/models/tournament_model.dart';

/// Builds a recent-activity timeline from tournament sub-collection data.
class TournamentActivityService {
  const TournamentActivityService();

  List<TournamentActivityItem> buildRecentActivity({
    required TournamentModel tournament,
    required List<MatchModel> matches,
    required List<TournamentGroupModel> groups,
    required List<TournamentOfficialModel> officials,
    required List<TournamentSponsorModel> sponsors,
    int limit = 10,
  }) {
    final items = <TournamentActivityItem>[];

    for (final match in matches) {
      final ts = match.scheduledAt ?? match.createdAt;
      if (ts == null) continue;
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.matchScheduled,
          title: 'Match scheduled',
          subtitle: _matchLabel(match),
          timestamp: ts,
          entityId: match.id,
        ),
      );
    }

    for (final group in groups) {
      final ts = group.createdAt;
      if (ts == null) continue;
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.groupCreated,
          title: 'Group created',
          subtitle: group.name,
          timestamp: ts,
          entityId: group.id,
        ),
      );
    }

    for (final official in officials) {
      final ts = official.createdAt;
      if (ts == null) continue;
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.officialAdded,
          title: 'Official added',
          subtitle: _officialLabel(official),
          timestamp: ts,
          entityId: official.id,
        ),
      );
    }

    for (final sponsor in sponsors) {
      final ts = sponsor.createdAt;
      if (ts == null) continue;
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.sponsorAdded,
          title: 'Sponsor added',
          subtitle: sponsor.name,
          timestamp: ts,
          entityId: sponsor.id,
        ),
      );
    }

    if (tournament.matchIds.isNotEmpty && tournament.updatedAt != null) {
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.fixtureGenerated,
          title: 'Fixtures updated',
          subtitle: '${tournament.matchIds.length} matches in tournament',
          timestamp: tournament.updatedAt!,
        ),
      );
    }

    if (tournament.teamIds.isNotEmpty && tournament.updatedAt != null) {
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.teamRegistered,
          title: 'Teams registered',
          subtitle: '${tournament.teamIds.length} teams in tournament',
          timestamp: tournament.updatedAt!,
        ),
      );
    }

    if (tournament.updatedAt != null) {
      items.add(
        TournamentActivityItem(
          type: TournamentActivityType.tournamentUpdated,
          title: 'Tournament updated',
          subtitle: tournament.name,
          timestamp: tournament.updatedAt!,
        ),
      );
    }

    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final seen = <String>{};
    final deduped = <TournamentActivityItem>[];
    for (final item in items) {
      final key = '${item.type.name}|${item.subtitle}|${item.timestamp.toIso8601String()}';
      if (seen.add(key)) deduped.add(item);
      if (deduped.length >= limit) break;
    }

    return deduped;
  }

  String _matchLabel(MatchModel match) {
    if (match.title.trim().isNotEmpty) return match.title.trim();
    if (match.teamAName.isNotEmpty || match.teamBName.isNotEmpty) {
      return '${match.teamAName} vs ${match.teamBName}';
    }
    return 'Match';
  }

  String _officialLabel(TournamentOfficialModel official) {
    final name = official.displayName.trim();
    final role = official.role.name;
    if (name.isEmpty) return role;
    return '$name · $role';
  }
}
