import '../../core/constants/enums.dart';
import '../../core/utils/match_score_display.dart';
import '../../core/utils/tournament_match_stage_utils.dart';
import '../../data/models/ball_event_model.dart';
import '../../data/models/match_model.dart';
import '../../data/models/match_revision_model.dart';
import '../../data/models/match_rules_model.dart';
import '../../data/models/match_setup_draft_models.dart';
import '../../data/models/match_timeline_event_model.dart';
import '../../domain/display/match_revision_display.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'match_analytics_models.dart';
import 'match_info_models.dart';
import 'match_phase_service.dart';

/// Builds read-only metadata for the Match Info tab from match snapshot data.
class MatchInfoService {
  MatchInfoSnapshot build({
    required MatchModel match,
    List<MatchRevisionModel> revisions = const [],
    List<MatchTimelineEventModel> timeline = const [],
    MatchAnalyticsSnapshot analytics = const MatchAnalyticsSnapshot(),
    List<BallEventModel> ballEvents = const [],
    String? tournamentName,
    String? tournamentRoundName,
    String? tournamentGroupName,
  }) {
    return MatchInfoSnapshot(
      overview: _overview(
        match,
        tournamentName,
        tournamentRoundName: tournamentRoundName,
        tournamentGroupName: tournamentGroupName,
      ),
      configuration: _configuration(match),
      officials: _officials(match),
      notes: _notes(
        match: match,
        revisions: revisions,
        timeline: timeline,
        ballEvents: ballEvents,
        analytics: analytics,
      ),
      adminEvents: _adminEvents(match, revisions, timeline),
      quickLinks: _quickLinks(match, tournamentName),
      conditions: _conditions(match),
      dlsSections: _dlsSections(match, revisions),
      penalties: _penalties(match, revisions),
      abandoned: _abandoned(match),
    );
  }

  List<MatchInfoRow> _overview(
    MatchModel match,
    String? tournamentName, {
    String? tournamentRoundName,
    String? tournamentGroupName,
  }) {
    final rules = match.rules;
    final rows = <MatchInfoRow>[];

    void add(
      String label,
      String value, {
      bool highlight = false,
      bool openDirectionsInMaps = false,
    }) {
      if (value.trim().isEmpty) return;
      rows.add(
        MatchInfoRow(
          label: label,
          value: value,
          highlight: highlight,
          openDirectionsInMaps: openDirectionsInMaps,
        ),
      );
    }

    if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
      add(
        'Tournament',
        tournamentName?.trim().isNotEmpty == true
            ? tournamentName!.trim()
            : 'Tournament match',
        highlight: true,
      );
    }
    if (match.matchType == MatchType.tournament) {
      add(
        'Match type',
        tournamentMatchTypeLabel(
          match,
          groupName: tournamentGroupName,
        ),
      );
      final round = tournamentMatchRoundLabel(
        match,
        roundName: tournamentRoundName,
        groupName: tournamentGroupName,
      );
      if (round != null && round.isNotEmpty) {
        add('Round', round);
      }
    }
    add('Format', _overviewFormatLabel(rules));
    add('Date & time', _dateTimeLabel(match));
    final venue = _venueLabel(match);
    if (venue.isNotEmpty) {
      add('Venue', venue, highlight: true, openDirectionsInMaps: true);
    }
    final publicId = match.publicMatchId?.trim();
    if (publicId != null && publicId.isNotEmpty) {
      add('Match ID', publicId);
    }
    add('Toss', ScoringDisplayUtils.tossSummaryLine(match) ?? '');
    add(
      'Result',
      _resultLabel(match),
      highlight: match.status == MatchStatus.completed,
    );

    return rows;
  }

  List<MatchInfoRow> _configuration(MatchModel match) {
    final rules = match.rules;
    final rows = <MatchInfoRow>[];

    void add(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(MatchInfoRow(label: label, value: value));
    }

    add('Overs per innings', '${rules.totalOvers}');
    add('Balls per over', '${rules.ballsPerOver}');
    add('Players per team', '${rules.playersPerTeam}');
    if (rules.ballType != null) {
      add('Ball type', _ballTypeLabel(rules.ballType!));
    }
    add('Powerplay settings', _powerplayLabel(rules));
    add('Indoor / outdoor', rules.isIndoor ? 'Indoor' : 'Outdoor');
    add('DLS enabled', _dlsSupportLabel(match));
    add('Custom rules', _customRulesLabel(rules));
    if (rules.oversPerBowler > 0) {
      add('Overs per bowler', '${rules.oversPerBowler}');
    }
    if (rules.notes != null && rules.notes!.trim().isNotEmpty) {
      add('Rules note', rules.notes!.trim());
    }

    return rows;
  }

  List<MatchInfoOfficial> _officials(MatchModel match) {
    final setup = match.setup;
    if (setup == null) return const [];

    final officials = <MatchInfoOfficial>[];

    void addEntries(List<MatchOfficialEntry> entries, String fallbackRole) {
      for (final entry in entries) {
        if (entry.name.trim().isEmpty) continue;
        officials.add(
          MatchInfoOfficial(
            name: entry.name.trim(),
            role: entry.slotLabel.trim().isNotEmpty
                ? entry.slotLabel.trim()
                : fallbackRole,
            playerId: entry.playerId,
            photoUrl: entry.photoUrl,
          ),
        );
      }
    }

    addEntries(setup.scorers, 'Scorer');
    addEntries(setup.umpires, 'Umpire');
    addEntries(setup.commentators, 'Commentator');
    addEntries(setup.liveStreamers, 'Streamer');
    if (setup.referee != null && setup.referee!.name.trim().isNotEmpty) {
      officials.add(
        MatchInfoOfficial(
          name: setup.referee!.name.trim(),
          role: setup.referee!.slotLabel.trim().isNotEmpty
              ? setup.referee!.slotLabel.trim()
              : 'Referee',
          playerId: setup.referee!.playerId,
          photoUrl: setup.referee!.photoUrl,
        ),
      );
    }

    return officials;
  }

  List<MatchInfoTimelineEntry> _notes({
    required MatchModel match,
    required List<MatchRevisionModel> revisions,
    required List<MatchTimelineEventModel> timeline,
    required List<BallEventModel> ballEvents,
    required MatchAnalyticsSnapshot analytics,
  }) {
    final entries = <MatchInfoTimelineEntry>[];

    void add(
      String title, {
      String subtitle = '',
      DateTime? timestamp,
    }) {
      entries.add(
        MatchInfoTimelineEntry(
          title: title,
          subtitle: subtitle,
          timestamp: timestamp,
        ),
      );
    }

    if (match.createdAt != null) {
      add('Match created', timestamp: match.createdAt);
    }

    final toss = ScoringDisplayUtils.tossSummaryLine(match);
    if (toss != null && toss.isNotEmpty) {
      add('Toss completed', subtitle: toss, timestamp: match.startedAt);
    }

    if (match.startedAt != null) {
      add('Match started', timestamp: match.startedAt);
    }

    for (final inn in match.innings) {
      final team = _battingTeamName(match, inn);
      add(
        'Innings ${inn.inningsNumber} started',
        subtitle: team,
        timestamp: match.startedAt,
      );
    }

    if (!match.rules.isTestMatch) {
      final phases = MatchPhaseService.forRules(match.rules);
      add('Powerplay started', subtitle: phases.powerplayLabel);
    }

    final sorted = [...ballEvents]..sort((a, b) => a.sequence.compareTo(b.sequence));
    final runsByInnings = <int, int>{};
    final milestonesHit = <int, Set<int>>{};

    for (final event in sorted) {
      if (!event.isLegalDelivery) continue;
      final inn = event.inningsNumber;
      runsByInnings[inn] = (runsByInnings[inn] ?? 0) + event.runs;
      final total = runsByInnings[inn]!;
      milestonesHit.putIfAbsent(inn, () => {});
      for (final milestone in [50, 100, 150, 200, 250]) {
        if (total >= milestone && !milestonesHit[inn]!.contains(milestone)) {
          milestonesHit[inn]!.add(milestone);
          add(
            '$milestone runs',
            subtitle: 'Innings $inn',
            timestamp: event.timestamp,
          );
        }
      }
    }

    for (final partnership
        in analytics.partnerships.where((p) => p.runs >= 50)) {
      add(
        'Partnership milestone',
        subtitle:
            '${partnership.batterAName} & ${partnership.batterBName} · ${partnership.runs} runs',
      );
    }

    for (final breakEntry in match.matchBreakHistory) {
      add(
        '${_titleCase(breakEntry.breakType)} break',
        subtitle: breakEntry.reason,
        timestamp: breakEntry.startTime,
      );
    }

    if (match.status == MatchStatus.inningsBreak || match.innings.length > 1) {
      add('Innings break', timestamp: match.completedAt);
    }

    for (final revision in revisions) {
      if (revision.type.contains('dls') ||
          revision.revisionMethod?.toUpperCase() == 'DLS') {
        add(
          'DLS applied',
          subtitle: revision.reason.isNotEmpty
              ? revision.reason
              : 'Target ${revision.oldTarget ?? '—'} → ${revision.newTarget ?? '—'}',
          timestamp: revision.createdAt,
        );
      } else if (revision.newTarget != null) {
        add(
          'Target revised',
          subtitle:
              '${revision.oldTarget ?? '—'} → ${revision.newTarget} · ${revision.reason}',
          timestamp: revision.createdAt,
        );
      }
      if (revision.penaltyRuns != null && revision.penaltyRuns != 0) {
        add(
          'Penalty runs added',
          subtitle: '${revision.penaltyRuns} runs · ${revision.reason}',
          timestamp: revision.createdAt,
        );
      }
    }

    for (final event in timeline) {
      if (_isAdminTimelineTitle(event.title)) continue;
      add(
        event.title,
        subtitle: event.subtitle,
        timestamp: event.createdAt,
      );
    }

    if (match.status == MatchStatus.completed) {
      add(
        'Match ended',
        subtitle: _resultLabel(match),
        timestamp: match.completedAt,
      );
      add(
        'Result declared',
        subtitle: _resultLabel(match),
        timestamp: match.completedAt,
      );
    } else if (match.status == MatchStatus.abandoned) {
      add(
        'Match abandoned',
        subtitle: match.targetState.abandonedReason ?? match.resultSummary,
        timestamp: match.completedAt,
      );
    }

    entries.sort((a, b) {
      final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    return entries;
  }

  List<MatchInfoTimelineEntry> _adminEvents(
    MatchModel match,
    List<MatchRevisionModel> revisions,
    List<MatchTimelineEventModel> timeline,
  ) {
    final entries = <MatchInfoTimelineEntry>[];

    void add(String title, {String subtitle = '', DateTime? timestamp}) {
      entries.add(
        MatchInfoTimelineEntry(
          title: title,
          subtitle: subtitle,
          timestamp: timestamp,
          isAdminEvent: true,
        ),
      );
    }

    for (final transfer in match.scorerTransferHistory) {
      add(
        'Scorer changed',
        subtitle: transfer.toUserName.isNotEmpty
            ? transfer.toUserName
            : transfer.toUserId,
        timestamp: transfer.timestamp,
      );
    }

    for (final revision in revisions) {
      final type = revision.type.toLowerCase();
      if (type.contains('target') || revision.newTarget != null) {
        add(
          'Target revised',
          subtitle:
              '${revision.oldTarget ?? '—'} → ${revision.newTarget ?? '—'} · ${revision.reason}',
          timestamp: revision.createdAt,
        );
      }
      if (type.contains('dls') ||
          revision.revisionMethod?.toUpperCase() == 'DLS') {
        add(
          'DLS applied',
          subtitle: revision.reason,
          timestamp: revision.createdAt,
        );
      }
      if (revision.penaltyRuns != null && revision.penaltyRuns != 0) {
        add(
          'Penalty runs',
          subtitle: '${revision.penaltyRuns} · ${revision.reason}',
          timestamp: revision.createdAt,
        );
      }
    }

    for (final event in timeline) {
      add(event.title, subtitle: event.subtitle, timestamp: event.createdAt);
    }

    if (match.status == MatchStatus.abandoned) {
      add(
        'Match abandoned',
        subtitle: match.targetState.abandonedReason ?? match.resultSummary,
        timestamp: match.completedAt,
      );
    }

    for (final inn in match.innings) {
      if (inn.penaltyRuns != 0) {
        add(
          'Penalty runs added',
          subtitle:
              '${_battingTeamName(match, inn)} · ${inn.penaltyRuns} · ${inn.penaltyReason}',
        );
      }
    }

    entries.sort((a, b) {
      final at = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bt = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bt.compareTo(at);
    });

    return entries;
  }

  List<MatchInfoQuickLink> _quickLinks(
    MatchModel match,
    String? tournamentName,
  ) {
    final links = <MatchInfoQuickLink>[];

    links.add(
      MatchInfoQuickLink(
        label: 'Squads',
        route: '/match/${match.id}?tab=squads',
        iconName: 'groups',
      ),
    );

    if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
      final tournamentId = match.tournamentId!;
      links.add(
        MatchInfoQuickLink(
          label: 'Points table',
          route: '/tournaments/$tournamentId/points-table',
          iconName: 'leaderboard',
        ),
      );
    }

    links.add(
      MatchInfoQuickLink(
        label: 'Leaderboard',
        route: '/match/${match.id}?tab=mvp',
        iconName: 'emoji_events',
      ),
    );

    if (match.tournamentId != null && match.tournamentId!.isNotEmpty) {
      links.add(
        MatchInfoQuickLink(
          label: 'Tournament',
          route: '/tournaments/${match.tournamentId}',
          iconName: 'trophy',
        ),
      );
    }

    if (match.teamAId != null && match.teamAId!.isNotEmpty) {
      links.add(
        MatchInfoQuickLink(
          label: match.teamAName.isNotEmpty ? match.teamAName : 'Team A',
          route: '/teams/${match.teamAId}',
          iconName: 'groups',
        ),
      );
    }
    if (match.teamBId != null && match.teamBId!.isNotEmpty) {
      links.add(
        MatchInfoQuickLink(
          label: match.teamBName.isNotEmpty ? match.teamBName : 'Team B',
          route: '/teams/${match.teamBId}',
          iconName: 'groups',
        ),
      );
    }

    return links;
  }

  List<MatchInfoRow> _conditions(MatchModel match) {
    final rules = match.rules;
    final rows = <MatchInfoRow>[];

    void add(String label, String value) {
      if (value.trim().isEmpty) return;
      rows.add(MatchInfoRow(label: label, value: value));
    }

    if (rules.pitchType != null) {
      add('Pitch type', _pitchTypeLabel(rules.pitchType!));
    }
    add('Day / night', _dayNightLabel(match));

    return rows;
  }

  List<MatchInfoDlsSection> _dlsSections(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    final sections = <MatchInfoDlsSection>[];
    final state = match.targetState;

    if (state.dlsApplied || state.revisionMethod?.toUpperCase() == 'DLS') {
      final rows = <MatchInfoRow>[
        const MatchInfoRow(label: 'DLS applied', value: 'Yes'),
        if (state.originalOvers != null && state.effectiveRevisedOvers != null)
          MatchInfoRow(
            label: 'Overs reduced',
            value: '${state.originalOvers} → ${state.effectiveRevisedOvers}',
          ),
        if (state.originalTarget != null)
          MatchInfoRow(
            label: 'Original target',
            value: '${state.originalTarget}',
          ),
        if (state.effectiveRevisedTarget != null)
          MatchInfoRow(
            label: 'Revised target',
            value: '${state.effectiveRevisedTarget}',
          ),
        if (state.abandonedReason != null &&
            state.abandonedReason!.trim().isNotEmpty)
          MatchInfoRow(label: 'Reason', value: state.abandonedReason!.trim()),
      ];
      sections.add(MatchInfoDlsSection(title: 'DLS revision', rows: rows));
    }

    for (final revision in revisions) {
      final isDls = revision.revisionMethod?.toUpperCase() == 'DLS' ||
          revision.type.toLowerCase().contains('dls');
      final isManualTarget = revision.newTarget != null && !isDls;
      if (!isDls && !isManualTarget) continue;

      final rows = <MatchInfoRow>[
        if (revision.originalOvers != null && revision.revisedOvers != null)
          MatchInfoRow(
            label: 'Overs',
            value: '${revision.originalOvers} → ${revision.revisedOvers}',
          ),
        if (revision.oldTarget != null)
          MatchInfoRow(label: 'Original target', value: '${revision.oldTarget}'),
        if (revision.newTarget != null)
          MatchInfoRow(label: 'Revised target', value: '${revision.newTarget}'),
        if (revision.reason.isNotEmpty)
          MatchInfoRow(label: 'Reason', value: revision.reason),
      ];
      sections.add(
        MatchInfoDlsSection(
          title: isDls ? 'DLS revision' : 'Target revision',
          rows: rows,
        ),
      );
    }

    return sections;
  }

  List<MatchInfoPenalty> _penalties(
    MatchModel match,
    List<MatchRevisionModel> revisions,
  ) {
    final penalties = <MatchInfoPenalty>[];

    for (final entry in MatchRevisionDisplay.penaltyEntries(match, revisions)) {
      penalties.add(
        MatchInfoPenalty(
          teamName: entry.source,
          runs: entry.runs,
          reason: entry.reason,
        ),
      );
    }

    return penalties;
  }

  MatchInfoAbandonedSection? _abandoned(MatchModel match) {
    if (match.status != MatchStatus.abandoned) return null;
    return MatchInfoAbandonedSection(
      reason: match.targetState.abandonedReason ??
          match.resultSummary.ifEmpty('Match abandoned'),
      timeLabel: _dateTimeLabel(match, useCompleted: true),
      resultStatus: match.targetState.matchOutcome ?? match.resultSummary,
    );
  }

  static String _venueLabel(MatchModel match) => match.venue.trim();

  static String _dateTimeLabel(MatchModel match, {bool useCompleted = false}) {
    final dt = useCompleted
        ? (match.completedAt ?? match.startedAt ?? match.scheduledAt)
        : (match.scheduledAt ?? match.startedAt ?? match.createdAt);
    if (dt == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    final year = dt.year % 100;
    return '${dt.day}-${months[dt.month - 1]}-$year '
        '${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }

  static String _overviewFormatLabel(MatchRulesModel rules) {
    if (rules.isTestMatch) return 'Test Match';
    if (rules.cricketMatchType == CricketMatchType.limitedOvers) {
      return 'Limited Overs · ${rules.totalOvers} overs';
    }
    if (rules.cricketMatchType == CricketMatchType.indoor) {
      return 'Indoor · ${rules.totalOvers} overs';
    }
    return _cricketMatchTypeLabel(rules);
  }

  static String _cricketMatchTypeLabel(MatchRulesModel rules) {
    return switch (rules.cricketMatchType) {
      CricketMatchType.testMatch => 'Test',
      CricketMatchType.limitedOvers => 'Limited Overs',
      CricketMatchType.indoor => 'Indoor',
    };
  }

  static String _ballTypeLabel(CricketBallType type) {
    return switch (type) {
      CricketBallType.leather => 'Leather',
      CricketBallType.tennis => 'Tennis',
      CricketBallType.indoor => 'Indoor',
    };
  }

  static String _pitchTypeLabel(PitchType type) {
    return switch (type) {
      PitchType.rough => 'Rough',
      PitchType.cement => 'Cement',
      PitchType.turf => 'Turf',
      PitchType.astroturf => 'Astroturf',
      PitchType.matting => 'Matting',
    };
  }

  static String _powerplayLabel(MatchRulesModel rules) {
    if (rules.isTestMatch) return 'Not applicable';
    final hasSlots = rules.powerplaySlots.any((slot) => slot.isNotEmpty);
    if (hasSlots) return 'Enabled';
    if (rules.powerplayOvers != null && rules.powerplayOvers! > 0) {
      return 'Enabled (${rules.powerplayOvers} overs)';
    }
    return 'Disabled';
  }

  static String _dlsSupportLabel(MatchModel match) {
    if (match.rules.isTestMatch) return 'Not applicable';
    if (match.targetState.dlsApplied) return 'Applied';
    return 'Available';
  }

  static String _customRulesLabel(MatchRulesModel rules) {
    if (rules.format == MatchFormat.custom) return 'Yes';
    if (rules.notes != null && rules.notes!.trim().isNotEmpty) return 'Yes';
    return 'No';
  }

  static String _dayNightLabel(MatchModel match) {
    final dt = match.scheduledAt ?? match.startedAt;
    if (dt == null) return '';
    return dt.hour >= 17 || dt.hour < 6 ? 'Day / Night' : 'Day';
  }

  static String _resultLabel(MatchModel match) {
    if (match.status == MatchStatus.abandoned) {
      return match.resultSummary.isNotEmpty
          ? match.resultSummary
          : match.targetState.abandonedReason ?? 'Abandoned';
    }
    if (match.status == MatchStatus.completed) {
      return MatchScoreDisplay.completedResultLine(match) ??
          match.resultSummary;
    }
    if (match.status == MatchStatus.live ||
        match.status == MatchStatus.inningsBreak) {
      return 'In progress';
    }
    return match.resultSummary;
  }

  static String _battingTeamName(MatchModel match, dynamic inn) {
    final teamId = inn.battingTeamId as String?;
    if (teamId == match.teamAId) return match.teamAName;
    if (teamId == match.teamBId) return match.teamBName;
    return '';
  }

  static bool _isAdminTimelineTitle(String title) {
    final lower = title.toLowerCase();
    return lower.contains('scorer') ||
        lower.contains('abandon') ||
        lower.contains('result declared');
  }

  static String _titleCase(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
