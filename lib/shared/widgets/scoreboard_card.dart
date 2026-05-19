import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/cricket_math.dart';
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
    final inn = innings ?? match.currentInnings;
    final rules = match.rules;
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
                if (isLive) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.liveIndicator,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'LIVE',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
              children: [
                _teamScore(context, match.teamAName, inn, match.teamAId),
                Text(
                  'vs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.gold,
                      ),
                ),
                _teamScore(context, match.teamBName, inn, match.teamBId),
              ],
            ),
            if (inn != null) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                '${CricketMath.formatOvers(inn.legalBalls, rules.ballsPerOver)} ov • RR ${CricketMath.runRate(inn.totalRuns, inn.legalBalls, rules.ballsPerOver).toStringAsFixed(2)}',
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
    InningsModel? inn,
    String? teamId,
  ) {
    final isBatting = inn != null && inn.battingTeamId == teamId;
    final score = isBatting ? '${inn.totalRuns}/${inn.totalWickets}' : '—';
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isBatting ? AppColors.gold : Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            score,
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }
}
