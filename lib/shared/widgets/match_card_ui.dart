import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/cf_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/match_score_display.dart';
import '../../core/utils/overs_formatter.dart';
import '../../data/models/match_model.dart';
import '../../domain/scoring/innings_completion_policy.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';
import 'match_team_avatar.dart';

enum MatchCardStyle {
  /// Surface card for feeds and lists.
  list,

  /// Broadcast scorebug for match hub / live hero.
  hero,
}

/// Shared status chip, meta, teams row, and result lines for match cards.
class MatchCardContent extends StatelessWidget {
  const MatchCardContent({
    super.key,
    required this.match,
    this.style = MatchCardStyle.list,
    this.tournamentLabel,
    this.roundLabel,
    this.showFooterHint = true,
    this.showChaseDetails = true,
    this.showTossLine = false,
    this.teamALogoUrl,
    this.teamBLogoUrl,
  });

  final MatchModel match;
  final MatchCardStyle style;
  final String? tournamentLabel;
  final String? roundLabel;
  final bool showFooterHint;
  final bool showChaseDetails;
  final bool showTossLine;
  final String? teamALogoUrl;
  final String? teamBLogoUrl;

  bool get _isHero => style == MatchCardStyle.hero;

  bool get _isUpcoming =>
      match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.tossCompleted;

  bool get _isLive =>
      match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  bool get _isCompleted => match.status == MatchStatus.completed;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final status = matchStatusUi(match, cf);
    final winnerA = MatchScoreDisplay.isTeamWinner(match, match.teamAId);
    final winnerB = MatchScoreDisplay.isTeamWinner(match, match.teamBId);
    final battingA = MatchScoreDisplay.isTeamBattingNow(match, match.teamAId);
    final battingB = MatchScoreDisplay.isTeamBattingNow(match, match.teamBId);
    final showScores = _isLive || _isCompleted;
    final chase = _isLive && showChaseDetails ? _cardChaseLine(match) : null;
    final result =
        _isCompleted ? MatchScoreDisplay.completedResultLine(match) : null;
    final cur = match.currentInnings;
    final rules = match.rules;

    final nameColor = _isHero ? Colors.white : cf.textPrimary;
    final mutedColor = _isHero ? Colors.white70 : cf.textSecondary;

    Color teamNameColor(bool winner, bool batting, bool loser) {
      if (_isHero) {
        if (winner || batting) return Colors.white;
        return Colors.white.withValues(alpha: 0.75);
      }
      if (winner || batting) return cf.scoreEmphasis;
      if (loser && _isCompleted) return cf.textMuted;
      return nameColor;
    }

    FontWeight teamWeight(bool winner, bool batting) {
      if (winner || batting || _isUpcoming) return FontWeight.w700;
      return FontWeight.w600;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (tournamentLabel != null ||
            (_isUpcoming &&
                roundLabel != null &&
                roundLabel!.trim().isNotEmpty)) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (tournamentLabel != null)
                Expanded(
                  child: Text(
                    tournamentLabel!,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              if (_isUpcoming &&
                  roundLabel != null &&
                  roundLabel!.trim().isNotEmpty) ...[
                if (tournamentLabel != null) const SizedBox(width: 8),
                MatchRoundBadge(label: roundLabel!.trim()),
              ],
            ],
          ),
          const SizedBox(height: 4),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                matchTypeDisplayLabel(match),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppDimens.spaceSm),
            MatchStatusChip(
              label: status.label,
              color: status.color,
              showLivePulse: status.label == 'LIVE',
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          matchCardMetaLine(match),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: mutedColor,
              ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        if (_isUpcoming) ...[
          _UpcomingTeamsBlock(
            teamAName: match.teamAName,
            teamBName: match.teamBName,
            teamALogoUrl: teamALogoUrl,
            teamBLogoUrl: teamBLogoUrl,
            nameColor: nameColor,
            isHero: _isHero,
          ),
          if (match.scheduledAt != null) ...[
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Match scheduled to begin on '
              '${AppDateUtils.formatCardSchedule(match.scheduledAt!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    height: 1.35,
                  ),
            ),
          ],
        ] else ...[
          _TeamScoreRow(
            name: match.teamAName,
            score: showScores
                ? matchCardScoreLine(match, match.teamAId)
                : null,
            logoUrl: teamALogoUrl,
            nameColor: teamNameColor(
              winnerA,
              battingA,
              !winnerA && _isCompleted,
            ),
            nameWeight: teamWeight(winnerA, battingA),
            isHero: _isHero,
          ),
          const SizedBox(height: 8),
          _TeamScoreRow(
            name: match.teamBName,
            score: showScores
                ? matchCardScoreLine(match, match.teamBId)
                : null,
            logoUrl: teamBLogoUrl,
            nameColor: teamNameColor(
              winnerB,
              battingB,
              !winnerB && _isCompleted,
            ),
            nameWeight: teamWeight(winnerB, battingB),
            isHero: _isHero,
          ),
        ],
        if (showTossLine &&
            cur != null &&
            ScoringDisplayUtils.showTossLineDuringFirstInnings(
              match,
              cur,
              rules,
            )) ...[
          const SizedBox(height: 6),
          Text(
            ScoringDisplayUtils.tossSummaryLine(match)!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
        if (chase != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            chase,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isHero ? Colors.white : cf.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ] else if (result != null) ...[
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            result,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _isHero ? Colors.white : cf.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ],
    );
  }

  static String? _cardChaseLine(MatchModel match) {
    final cur = match.currentInnings;
    final first = MatchScoreDisplay.completedFirstInnings(match);
    if (cur == null ||
        first == null ||
        cur.inningsNumber < 2 ||
        cur.status != InningsStatus.inProgress) {
      return MatchScoreDisplay.chaseLine(match);
    }
    final rules = InningsCompletionPolicy.effectiveRules(match, cur);
    final target = first.target;
    final runsNeeded = (target - cur.totalRuns).clamp(0, 9999);
    final ballsRemaining =
        (rules.totalBalls - cur.legalBalls).clamp(0, rules.totalBalls);
    if (runsNeeded <= 0) return 'Target reached';
    if (ballsRemaining <= 0) return 'Need $runsNeeded runs';
    return 'Need $runsNeeded runs from $ballsRemaining balls';
  }
}

class _UpcomingTeamsBlock extends StatelessWidget {
  const _UpcomingTeamsBlock({
    required this.teamAName,
    required this.teamBName,
    this.teamALogoUrl,
    this.teamBLogoUrl,
    required this.nameColor,
    required this.isHero,
  });

  final String teamAName;
  final String teamBName;
  final String? teamALogoUrl;
  final String? teamBLogoUrl;
  final Color nameColor;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: nameColor,
          height: 1.25,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _UpcomingTeamLine(
          name: teamAName,
          logoUrl: teamALogoUrl,
          style: style,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            'vs',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: isHero
                      ? Colors.white54
                      : context.cf.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        _UpcomingTeamLine(
          name: teamBName,
          logoUrl: teamBLogoUrl,
          style: style,
        ),
      ],
    );
  }
}

class _UpcomingTeamLine extends StatelessWidget {
  const _UpcomingTeamLine({
    required this.name,
    this.logoUrl,
    required this.style,
  });

  final String name;
  final String? logoUrl;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        MatchTeamAvatar(name: name, logoUrl: logoUrl, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: style,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _TeamScoreRow extends StatelessWidget {
  const _TeamScoreRow({
    required this.name,
    required this.score,
    this.logoUrl,
    required this.nameColor,
    required this.nameWeight,
    required this.isHero,
  });

  final String name;
  final String? score;
  final String? logoUrl;
  final Color nameColor;
  final FontWeight nameWeight;
  final bool isHero;

  @override
  Widget build(BuildContext context) {
    final scoreStyle = isHero
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: nameColor,
            );

    return Row(
      children: [
        MatchTeamAvatar(name: name, logoUrl: logoUrl, size: 26),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: nameWeight,
                  color: nameColor,
                  height: 1.2,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (score != null) ...[
          const SizedBox(width: 8),
          Text(
            score!,
            style: scoreStyle,
            textAlign: TextAlign.right,
          ),
        ],
      ],
    );
  }
}

class MatchRoundBadge extends StatelessWidget {
  const MatchRoundBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cf.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cf.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cf.accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({
    super.key,
    required this.label,
    required this.color,
    this.showLivePulse = false,
  });

  final String label;
  final Color color;
  final bool showLivePulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLivePulse) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

({String label, Color color}) matchStatusUi(MatchModel match, CfColors cf) {
  if (match.isMatchBreakActive) {
    final breakType = match.activeMatchBreak!.breakType.toLowerCase();
    if (breakType.contains('rain')) {
      return (label: 'Rain Delay', color: cf.info);
    }
    if (breakType.contains('lunch')) {
      return (label: 'Lunch', color: cf.info);
    }
    if (breakType.contains('drink')) {
      return (label: 'Drinks', color: cf.info);
    }
    if (breakType.contains('stump')) {
      return (label: 'Stumps', color: cf.statusCompleted);
    }
    return (
      label: match.activeMatchBreak!.breakType,
      color: cf.info,
    );
  }

  return switch (match.status) {
    MatchStatus.live => (label: 'LIVE', color: cf.statusLive),
    MatchStatus.inningsBreak => (label: 'BREAK', color: cf.info),
    MatchStatus.scheduled ||
    MatchStatus.tossCompleted ||
    MatchStatus.draft => (
        label: 'Upcoming',
        color: cf.statusUpcoming,
      ),
    MatchStatus.completed => (
        label: 'Result',
        color: cf.statusCompleted,
      ),
    MatchStatus.abandoned => (
        label: 'Abandoned',
        color: cf.textMuted,
      ),
  };
}

String matchTypeDisplayLabel(MatchModel match) {
  if (match.matchType == MatchType.tournament) {
    if (match.title.isNotEmpty && match.title != 'Match') {
      return match.title;
    }
    return 'Tournament Match';
  }
  final lower = match.title.toLowerCase();
  if (lower.contains('practice')) return 'Practice Match';
  if (lower.contains('friendly')) return 'Friendly Match';
  if (lower.contains('league')) return 'League Match';
  return 'Individual Match';
}

String matchCardMetaLine(MatchModel match) {
  final parts = <String>[];
  final date = match.scheduledAt ?? match.startedAt ?? match.completedAt;
  if (date != null) {
    parts.add(AppDateUtils.formatCardDate(date));
  }
  parts.add('${match.rules.totalOvers} Ov.');
  if (match.venue.isNotEmpty) {
    parts.add(match.venue);
  } else if (match.location.displayLabel.isNotEmpty) {
    parts.add(match.location.displayLabel);
  }
  return parts.join(' | ');
}

String? matchCardScoreLine(MatchModel match, String? teamId) {
  final inn = MatchScoreDisplay.inningsBattingTeam(match, teamId);
  if (inn == null) return null;
  final rules = InningsCompletionPolicy.effectiveRules(match, inn);
  final overs = OversFormatter.formatOvers(inn.legalBalls, rules.ballsPerOver);
  return '${inn.totalRuns}/${inn.totalWickets} ($overs)';
}

String matchCardFooterHint(MatchModel match) {
  return '';
}

BoxDecoration matchListCardDecoration(MatchModel match, BuildContext context) {
  final cf = context.cf;
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  return BoxDecoration(
    color: cf.card,
    borderRadius: BorderRadius.circular(16),
    border: isLive
        ? Border.all(color: cf.statusLive.withValues(alpha: 0.35))
        : Border.all(color: cf.border.withValues(alpha: cf.isLight ? 0.6 : 1)),
    boxShadow: [
      BoxShadow(
        color: isLive
            ? cf.statusLive.withValues(alpha: cf.isLight ? 0.08 : 0.14)
            : cf.cardShadow,
        blurRadius: isLive ? 12 : 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

BoxDecoration matchHeroCardDecoration(MatchModel match, BuildContext context) {
  final cf = context.cf;
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;

  if (isLive) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [cf.scoreboardBg, const Color(0xFF1565C0)],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: CfColors.primaryBlue.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  return BoxDecoration(
    color: cf.card,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: cf.border),
    boxShadow: [
      BoxShadow(
        color: cf.cardShadow,
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}