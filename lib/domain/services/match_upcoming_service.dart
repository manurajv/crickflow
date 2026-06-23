import 'package:intl/intl.dart';

import '../../data/models/match_model.dart';
import '../../data/models/match_player_snapshot.dart';
import '../../data/models/player_model.dart';
import '../../data/models/team_model.dart';
import '../../domain/scoring/match_lifecycle.dart';
import 'head_to_head_service.dart';
import 'match_info_service.dart';
import 'match_upcoming_models.dart';
import 'upcoming_milestones_service.dart';

/// Read-only pre-match hub snapshot.
class MatchUpcomingService {
  MatchUpcomingService({
    HeadToHeadService? headToHead,
    UpcomingMilestonesService? milestones,
    MatchInfoService? info,
  })  : _headToHead = headToHead ?? HeadToHeadService(),
        _milestones = milestones ?? UpcomingMilestonesService(),
        _info = info ?? MatchInfoService();

  final HeadToHeadService _headToHead;
  final UpcomingMilestonesService _milestones;
  final MatchInfoService _info;

  UpcomingMatchSnapshot build({
    required MatchModel match,
    required List<MatchModel> headToHeadHistory,
    TeamModel? teamA,
    TeamModel? teamB,
    String? tournamentName,
    List<MatchPlayerSnapshot> squadPlayers = const [],
    List<PlayerModel> milestonePlayers = const [],
  }) {
    if (!MatchLifecycle.isUpcoming(match)) return UpcomingMatchSnapshot.empty;

    final info = _info.build(match: match, tournamentName: tournamentName);
    final preview = _preview(match, teamA, teamB);
    final headToHead = _headToHead.build(
      upcoming: match,
      history: headToHeadHistory,
    );
    final infoRows = [...info.overview, ...info.configuration];
    final milestones = milestonePlayers.isNotEmpty
        ? _milestones.buildFromPlayers(milestonePlayers)
        : _milestones.buildFromSnapshots(squadPlayers);

    return UpcomingMatchSnapshot(
      preview: preview,
      headToHead: headToHead,
      infoRows: infoRows,
      officials: info.officials,
      milestones: milestones,
      banners: _banners(match),
      tournamentId: match.tournamentId,
      teamAId: match.teamAId,
      teamBId: match.teamBId,
    );
  }

  UpcomingMatchPreview _preview(
    MatchModel match,
    TeamModel? teamA,
    TeamModel? teamB,
  ) {
    final rules = match.rules;
    final scheduled = match.scheduledAt;
    return UpcomingMatchPreview(
      teamAName: match.teamAName,
      teamBName: match.teamBName,
      teamALogoUrl: teamA?.profileImageUrl,
      teamBLogoUrl: teamB?.profileImageUrl,
      formatLabel: '${rules.totalOvers} Overs',
      venueLabel: _venueLabel(match),
      dateLabel: scheduled != null
          ? DateFormat('d MMM yyyy').format(scheduled)
          : '',
      timeLabel:
          scheduled != null ? DateFormat('h:mm a').format(scheduled) : '',
      scheduledAt: scheduled,
      statusBadge: MatchLifecycle.upcomingBadgeLabel(match),
    );
  }

  static String _venueLabel(MatchModel match) => match.venue.trim();

  List<UpcomingMatchBanner> _banners(MatchModel match) {
    if (match.mediaByCode.isEmpty) return const [];
    return match.mediaByCode.entries
        .map(
          (e) => UpcomingMatchBanner(
            title: _bannerTitle(e.key),
            imageUrl: e.value,
            kind: e.key.toLowerCase(),
          ),
        )
        .toList();
  }

  static String _bannerTitle(String code) => switch (code.toUpperCase()) {
        'VS' => 'VS Banner',
        'TOURNAMENT' => 'Tournament Banner',
        'MATCHDAY' => 'Match Day Banner',
        'PROMO' => 'Promotional Banner',
        _ => 'Match Banner',
      };
}
