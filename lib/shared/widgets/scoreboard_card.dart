import 'package:flutter/material.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/cricket_math.dart';
import '../../core/utils/match_score_display.dart';
import '../../data/models/innings_model.dart';
import '../../data/models/match_model.dart';

class ScoreboardCard extends StatelessWidget {
  const ScoreboardCard({
    super.key,
    required this.match,
    this.innings,
    this.isLive = false,
  });

  final MatchModel match;
  final InningsModel? innings;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final cur = innings ?? match.currentInnings;
    final rules = match.rules;
    final firstSummary = MatchScoreDisplay.completedFirstInnings(match);
    final chase = MatchScoreDisplay.chaseLine(match);
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.scoreboardBg, Color(0xFF1565C0)],
        ),
        borderRadius: AppDimens.cardRadius,
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isLive || match.status == MatchStatus.inningsBreak) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: match.status == MatchStatus.inningsBreak
                          ? AppColors.gold
                          : AppColors.liveIndicator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      match.status == MatchStatus.inningsBreak
                          ? 'INN BREAK'
                          : 'LIVE',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: match.status == MatchStatus.inningsBreak
                                ? Colors.black
                                : Colors.white,
                            fontSize: 9,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                ],
                Expanded(
                  child: Text(
                    match.title,
                    style: titleStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _teamScore(context, match.teamAName, match.teamAId),
                Text(
                  'vs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
                _teamScore(
                  context,
                  match.teamBName,
                  match.teamBId,
                  alignEnd: true,
                ),
              ],
            ),
            if (firstSummary != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                '1st inn — ${firstSummary.battingTeamName}: '
                '${firstSummary.runs}/${firstSummary.wickets} '
                '(${firstSummary.overs} ov) · RR ${firstSummary.runRate.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
              ),
              Text(
                'Target ${firstSummary.target}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
            if (cur != null &&
                cur.status == InningsStatus.inProgress &&
                cur.inningsNumber >= 2) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                '${MatchScoreDisplay.battingTeamName(match, cur)} batting · '
                '${CricketMath.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
                'CRR ${MatchScoreDisplay.runRateFor(cur, rules).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (chase != null)
                Text(
                  chase,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w600,
                      ),
                ),
            ] else if (cur != null &&
                cur.status == InningsStatus.inProgress &&
                firstSummary == null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                '${CricketMath.formatOvers(cur.legalBalls, rules.ballsPerOver)} ov · '
                'RR ${MatchScoreDisplay.runRateFor(cur, rules).toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _teamScore(
    BuildContext context,
    String name,
    String? teamId, {
    bool alignEnd = false,
  }) {
    final inn = MatchScoreDisplay.inningsBattingTeam(match, teamId);
    final isBatting = MatchScoreDisplay.isTeamBattingNow(match, teamId);
    return Flexible(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isBatting ? AppColors.gold : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          ),
          if (inn != null)
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
              child: Text(
                '${inn.totalRuns}/${inn.totalWickets}',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                    ),
              ),
            )
          else
            Text(
              '—',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                  ),
            ),
        ],
      ),
    );
  }
}
