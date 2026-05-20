import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/innings_model.dart';
import '../../../../data/models/match_model.dart';
import '../../../../data/models/match_rules_model.dart';
import '../utils/scoring_display_utils.dart';

/// Scoreboard header — centered, CrickFlow theme.
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
    final oversText =
        ScoringDisplayUtils.inningsOversDisplay(innings, rules);
    final crr = ScoringDisplayUtils.currentRunRate(innings, rules);
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, rules);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 8,
            child: Icon(
              Icons.sports_cricket,
              size: 80,
              color: AppColors.gold.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceMd,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (ppLabel != null) ...[
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.6),
                              ),
                            ),
                            child: Text(
                              ppLabel,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          '${innings.totalRuns}/${innings.totalWickets}',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '($oversText/${rules.totalOvers})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'CRR ${crr.toStringAsFixed(2)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (innings.extras > 0) ...[
                        Text(
                          '  ·  ',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted.withValues(alpha: 0.8),
                          ),
                        ),
                        Text(
                          'Extras ${innings.extras}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (chase != null && chase.isChasing) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Need ${chase.runsNeeded} runs in ${chase.ballsRemaining} balls',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CRR ${chase.currentRunRate.toStringAsFixed(2)} · '
                      'RRR ${chase.requiredRunRate.toStringAsFixed(2)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (chase != null && !chase.isChasing) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Target ${chase.target} reached',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentGreen,
                      ),
                    ),
                  ],
                  if (tossLine != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      tossLine,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (innings.isFreeHitActive) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'FREE HIT',
                      textAlign: TextAlign.center,
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
          ),
        ],
      ),
    );
  }
}
