import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/match_score_display.dart';
import '../../data/models/match_model.dart';
import '../../features/scoring/presentation/utils/scoring_display_utils.dart';

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
    this.showFooterHint = true,
    this.showChaseDetails = true,
    this.showTossLine = false,
  });

  final MatchModel match;
  final MatchCardStyle style;
  final String? tournamentLabel;
  final bool showFooterHint;
  final bool showChaseDetails;
  final bool showTossLine;

  bool get _isHero => style == MatchCardStyle.hero;

  @override
  Widget build(BuildContext context) {
    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inningsBreak;
    final isCompleted = match.status == MatchStatus.completed;
    final status = matchStatusUi(match.status);
    final winnerA = MatchScoreDisplay.isTeamWinner(match, match.teamAId);
    final winnerB = MatchScoreDisplay.isTeamWinner(match, match.teamBId);
    final battingA = MatchScoreDisplay.isTeamBattingNow(match, match.teamAId);
    final battingB = MatchScoreDisplay.isTeamBattingNow(match, match.teamBId);
    final scoreA = MatchScoreDisplay.scoreForTeam(match, match.teamAId);
    final scoreB = MatchScoreDisplay.scoreForTeam(match, match.teamBId);
    final showScores = isLive || isCompleted || scoreA != null || scoreB != null;
    final chase = isLive && showChaseDetails
        ? MatchScoreDisplay.chaseLine(match)
        : null;
    final result =
        isCompleted ? MatchScoreDisplay.completedResultLine(match) : null;
    final firstSummary = isCompleted
        ? null
        : MatchScoreDisplay.completedFirstInnings(match);
    final cur = match.currentInnings;
    final rules = match.rules;

    final nameColor = _isHero ? Colors.white : AppColors.textPrimary;
    final mutedColor = _isHero ? Colors.white70 : AppColors.textSecondary;
    final scoreStyle = _isHero
        ? Theme.of(context).textTheme.displayMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              height: 1,
            )
        : Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            );

    Color teamNameColor(bool winner, bool batting) {
      if (winner || batting) return AppColors.gold;
      return _isHero ? Colors.white.withValues(alpha: 0.88) : nameColor;
    }

    Color teamScoreColor(bool winner, bool batting) {
      if (winner || batting) return AppColors.gold;
      return _isHero ? Colors.white : nameColor;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            MatchStatusChip(label: status.label, color: status.color),
            const SizedBox(width: AppDimens.spaceSm),
            Expanded(
              child: Text(
                matchCardMetaLine(match),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: mutedColor,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        if (tournamentLabel != null) ...[
          const SizedBox(height: 6),
          Text(
            tournamentLabel!,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppDimens.spaceSm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _TeamColumn(
                name: match.teamAName,
                score: showScores ? (scoreA ?? '—') : null,
                alignEnd: false,
                nameColor: teamNameColor(winnerA, battingA),
                scoreStyle: scoreStyle?.copyWith(
                  color: teamScoreColor(winnerA, battingA),
                ),
                nameWeight:
                    winnerA || battingA ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'vs',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: _TeamColumn(
                name: match.teamBName,
                score: showScores ? (scoreB ?? '—') : null,
                alignEnd: true,
                nameColor: teamNameColor(winnerB, battingB),
                scoreStyle: scoreStyle?.copyWith(
                  color: teamScoreColor(winnerB, battingB),
                ),
                nameWeight:
                    winnerB || battingB ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
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
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
        if (firstSummary != null && showChaseDetails) ...[
          const SizedBox(height: 6),
          Text(
            '1st inn ${firstSummary.runs}/${firstSummary.wickets} '
            '(${firstSummary.overs} ov) · Target ${firstSummary.target}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                ),
          ),
        ],
        if (cur != null &&
            showChaseDetails &&
            cur.status == InningsStatus.inProgress &&
            cur.inningsNumber >= 2 &&
            firstSummary != null) ...[
          const SizedBox(height: 4),
          Text(
            '${MatchScoreDisplay.battingTeamName(match, cur)} · '
            '${CricketMath.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
            'CRR ${MatchScoreDisplay.runRateFor(cur, rules).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                ),
          ),
        ] else if (cur != null &&
            showChaseDetails &&
            cur.status == InningsStatus.inProgress &&
            firstSummary == null &&
            isLive) ...[
          const SizedBox(height: 4),
          Text(
            '${CricketMath.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
            'RR ${MatchScoreDisplay.runRateFor(cur, rules).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                ),
          ),
        ],
        if (chase != null) ...[
          const SizedBox(height: 6),
          Text(
            chase,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ] else if (result != null) ...[
          const SizedBox(height: 6),
          Text(
            result,
            textAlign: _isHero ? TextAlign.center : TextAlign.start,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
        if (showFooterHint && !_isHero) ...[
          if (matchCardFooterHint(match).isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              matchCardFooterHint(match),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ],
        ],
      ],
    );
  }
}

class MatchStatusChip extends StatelessWidget {
  const MatchStatusChip({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _TeamColumn extends StatelessWidget {
  const _TeamColumn({
    required this.name,
    required this.score,
    required this.alignEnd,
    required this.nameColor,
    required this.scoreStyle,
    required this.nameWeight,
  });

  final String name;
  final String? score;
  final bool alignEnd;
  final Color nameColor;
  final TextStyle? scoreStyle;
  final FontWeight nameWeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          name,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: nameWeight,
                color: nameColor,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (score != null) ...[
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            child: Text(score!, style: scoreStyle),
          ),
        ],
      ],
    );
  }
}

({String label, Color color}) matchStatusUi(MatchStatus status) {
  return switch (status) {
    MatchStatus.live || MatchStatus.inningsBreak => (
        label: 'Live',
        color: AppColors.liveIndicator,
      ),
    MatchStatus.scheduled ||
    MatchStatus.tossCompleted ||
    MatchStatus.draft => (
        label: 'Upcoming',
        color: AppColors.gold,
      ),
    MatchStatus.completed => (
        label: 'Result',
        color: AppColors.primaryBlueLight,
      ),
    MatchStatus.abandoned => (
        label: 'Abandoned',
        color: AppColors.textMuted,
      ),
  };
}

String matchCardMetaLine(MatchModel match) {
  final parts = <String>[];
  if (match.scheduledAt != null) {
    parts.add(AppDateUtils.formatShort(match.scheduledAt!));
  }
  parts.add('${match.rules.totalOvers} Ov');
  if (match.venue.isNotEmpty) {
    parts.add(match.venue);
  } else if (match.location.displayLabel.isNotEmpty) {
    parts.add(match.location.displayLabel);
  }
  return parts.join(' · ');
}

String matchCardFooterHint(MatchModel match) {
  if (match.status == MatchStatus.completed) return '';
  if (match.status == MatchStatus.scheduled && match.scheduledAt != null) {
    return 'Scheduled · ${AppDateUtils.formatShort(match.scheduledAt!)}';
  }
  if (match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak) {
    return '';
  }
  return '';
}

BoxDecoration matchListCardDecoration(MatchModel match) {
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;
  return BoxDecoration(
    color: AppColors.card,
    borderRadius: AppDimens.cardRadius,
    border: Border.all(
      color: isLive
          ? AppColors.liveIndicator.withValues(alpha: 0.45)
          : AppColors.border,
    ),
    boxShadow: isLive
        ? [
            BoxShadow(
              color: AppColors.liveIndicator.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
        : null,
  );
}

BoxDecoration matchHeroCardDecoration(MatchModel match) {
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;
  final isCompleted = match.status == MatchStatus.completed;

  if (isLive) {
    return BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.scoreboardBg, Color(0xFF1565C0)],
      ),
      borderRadius: AppDimens.cardRadius,
      boxShadow: [
        BoxShadow(
          color: AppColors.primaryBlue.withValues(alpha: 0.35),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  if (isCompleted) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.surfaceElevated,
          AppColors.card,
        ],
      ),
      borderRadius: AppDimens.cardRadius,
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
    );
  }

  return BoxDecoration(
    color: AppColors.card,
    borderRadius: AppDimens.cardRadius,
    border: Border.all(color: AppColors.border),
  );
}
