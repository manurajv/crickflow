import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../utils/scoring_display_utils.dart';

/// Scoreboard header with toss line and powerplay badge (reference-style).
class LiveScoringHeader extends StatelessWidget {
  const LiveScoringHeader({
    super.key,
    required this.match,
    required this.innings,
    required this.rules,
    this.onShare,
  });

  final MatchModel match;
  final InningsModel innings;
  final MatchRulesModel rules;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final tossLine = ScoringDisplayUtils.tossSummaryLine(match);
    final ppLabel =
        ScoringDisplayUtils.activePowerplayLabel(match, innings);
    final oversDone = innings.legalBalls / rules.ballsPerOver;
    final oversText = oversDone == oversDone.roundToDouble()
        ? '${oversDone.toInt()}'
        : oversDone.toStringAsFixed(1);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF121820),
            Color(0xFF1A2332),
            AppColors.surface,
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 24,
            top: 8,
            child: Icon(
              Icons.fence_outlined,
              size: 72,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              AppDimens.spaceMd,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (ppLabel != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      ppLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${innings.totalRuns}/${innings.totalWickets}',
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '($oversText/${rules.totalOvers})',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFB0BEC5),
                      ),
                    ),
                  ],
                ),
                if (tossLine != null) ...[
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    tossLine,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ],
                if (innings.isFreeHitActive) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'FREE HIT',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
