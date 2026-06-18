import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/match_score_display.dart';
import '../../core/utils/overs_formatter.dart';
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

  bool get _isUpcoming =>
      match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.tossCompleted;

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
    final scoreA = MatchScoreDisplay.scoreForTeam(
      match,
      match.teamAId,
      showManualEndReason: false,
    );
    final scoreB = MatchScoreDisplay.scoreForTeam(
      match,
      match.teamBId,
      showManualEndReason: false,
    );
    final showScores =
        isLive || isCompleted || scoreA != null || scoreB != null;
    final chase = isLive && showChaseDetails
        ? MatchScoreDisplay.chaseLine(match)
        : null;
    final result =
        isCompleted ? MatchScoreDisplay.completedResultLine(match) : null;
    final firstSummary =
        isCompleted ? null : MatchScoreDisplay.completedFirstInnings(match);
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
        // ── status chip + meta (overs · venue, no date) ─────────────────
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

        // ── upcoming: date + time block ──────────────────────────────────
        if (_isUpcoming && match.scheduledAt != null && !_isHero) ...[
          const SizedBox(height: AppDimens.spaceSm),
          _UpcomingDateBlock(scheduledAt: match.scheduledAt!),
        ],

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

        // ── teams row ────────────────────────────────────────────────────
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
            '(${firstSummary.overs} ov) · Target ${firstSummary.target}'
            '${match.targetState.dlsApplied ? ' (DLS)' : ''}',
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
            '${OversFormatter.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
            'CRR ${MatchScoreDisplay.runRateFor(cur, rules, match: match).toStringAsFixed(2)}',
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
            '${OversFormatter.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
            'RR ${MatchScoreDisplay.runRateFor(cur, rules, match: match).toStringAsFixed(2)}',
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
      ],
    );
  }
}

/// Date + time block shown on upcoming match cards.
class _UpcomingDateBlock extends StatelessWidget {
  const _UpcomingDateBlock({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final matchDay =
        DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);

    final String dayLabel;
    if (matchDay == today) {
      dayLabel = 'Today';
    } else if (matchDay == tomorrow) {
      dayLabel = 'Tomorrow';
    } else {
      dayLabel = AppDateUtils.formatShortDay(scheduledAt); // e.g. "Wed, 18 Jun"
    }

    final timeLabel = AppDateUtils.formatTime(scheduledAt); // e.g. "3:30 PM"

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 12,
            color: AppColors.gold,
          ),
          const SizedBox(width: 5),
          Text(
            dayLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
              height: 1,
            ),
          ),
          Container(
            width: 1,
            height: 10,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            color: AppColors.gold.withValues(alpha: 0.4),
          ),
          const Icon(
            Icons.access_time_outlined,
            size: 12,
            color: AppColors.gold,
          ),
          const SizedBox(width: 4),
          Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
              height: 1,
            ),
          ),
        ],
      ),
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
  // Date is shown in the dedicated _UpcomingDateBlock for upcoming matches,
  // and not needed in the meta line for live/completed either — venue is enough.
  parts.add('${match.rules.totalOvers} Ov');
  if (match.venue.isNotEmpty) {
    parts.add(match.venue);
  } else if (match.location.displayLabel.isNotEmpty) {
    parts.add(match.location.displayLabel);
  }
  return parts.join(' · ');
}

String matchCardFooterHint(MatchModel match) {
  // Upcoming date/time is now shown in _UpcomingDateBlock inside MatchCardContent.
  // Footer hint is only used for non-standard states.
  if (match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak ||
      match.status == MatchStatus.completed ||
      match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.tossCompleted) {
    return '';
  }
  return '';
}

BoxDecoration matchListCardDecoration(MatchModel match) {
  final isLive = match.status == MatchStatus.live ||
      match.status == MatchStatus.inningsBreak;
  final isUpcoming = match.status == MatchStatus.scheduled ||
      match.status == MatchStatus.draft ||
      match.status == MatchStatus.tossCompleted;

  if (isLive) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: AppDimens.cardRadius,
      border: Border.all(
        color: AppColors.liveIndicator.withValues(alpha: 0.45),
      ),
      boxShadow: [
        BoxShadow(
          color: AppColors.liveIndicator.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  if (isUpcoming) {
    return BoxDecoration(
      color: AppColors.card,
      borderRadius: AppDimens.cardRadius,
      border: Border.all(
        color: AppColors.gold.withValues(alpha: 0.45),
        width: 1,
      ),
    );
  }

  return BoxDecoration(
    color: AppColors.card,
    borderRadius: AppDimens.cardRadius,
    border: Border.all(color: AppColors.border),
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
