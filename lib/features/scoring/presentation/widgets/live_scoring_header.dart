import 'package:flutter/material.dart';
import '../../../../core/theme/cf_colors.dart';
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
    final cf = context.cf;
    final tossLine = ScoringDisplayUtils.showTossLineDuringFirstInnings(
            match, innings, rules)
        ? ScoringDisplayUtils.tossSummaryLine(match)
        : null;
    final ppLabel =
        ScoringDisplayUtils.activePowerplayLabel(match, innings);
    final oversText =
        ScoringDisplayUtils.inningsOversDisplay(innings, rules);
    final crr = ScoringDisplayUtils.currentRunRate(innings, rules);
    final chase = ScoringDisplayUtils.chaseDisplay(match, innings, rules);
    final heroEmphasis = cf.isLight ? Colors.white : CfColors.gold;

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: cf.heroGradient,
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 8,
            child: Icon(
              Icons.sports_cricket,
              size: 80,
              color: cf.isLight
                  ? Colors.white.withValues(alpha: 0.08)
                  : CfColors.gold.withValues(alpha: 0.08),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceMd,
                vertical: AppDimens.spaceSm,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _headerContent(
                    cf: cf,
                    heroEmphasis: heroEmphasis,
                    tossLine: tossLine,
                    ppLabel: ppLabel,
                    oversText: oversText,
                    crr: crr,
                    chase: chase,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _headerContent({
    required CfColors cf,
    required Color heroEmphasis,
    required String? tossLine,
    required String? ppLabel,
    required String oversText,
    required double crr,
    required InningsChaseDisplay? chase,
  }) {
    return [
      Row(
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
                color: CfColors.primaryBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: cf.isLight
                      ? Colors.white.withValues(alpha: 0.6)
                      : CfColors.gold.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                ppLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: heroEmphasis,
                ),
              ),
            ),
          ],
          Text(
            '${innings.totalRuns}/${innings.totalWickets}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: Colors.white,
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
              color: Colors.white70,
            ),
          ),
        ],
      ),
      if (tossLine != null) ...[
        const SizedBox(height: 6),
        Text(
          tossLine,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
            height: 1.3,
          ),
        ),
      ],
      const SizedBox(height: 6),
      Text(
        innings.extras > 0
            ? 'CRR ${crr.toStringAsFixed(2)}  ·  Extras ${innings.extras}'
            : 'CRR ${crr.toStringAsFixed(2)}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      ),
        if (chase != null && chase.isChasing) ...[
        const SizedBox(height: 6),
        if (match.targetState.originalTarget != null &&
            match.targetState.effectiveRevisedTarget != null &&
            match.targetState.originalTarget !=
                match.targetState.effectiveRevisedTarget)
          Text(
            'Target: ${match.targetState.originalTarget} → '
            '${match.targetState.effectiveRevisedTarget}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        Text(
          'Target ${chase.target}'
          '${match.targetState.dlsApplied ? ' (DLS)' : ''} · '
          'Need ${chase.runsNeeded} off ${chase.ballsRemaining}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: heroEmphasis,
            height: 1.25,
          ),
        ),
        Text(
          'RRR ${chase.requiredRunRate.toStringAsFixed(2)}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ] else if (chase != null && !chase.isChasing) ...[
        const SizedBox(height: 6),
        Text(
          'Target ${chase.target} reached',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: cf.success,
          ),
        ),
      ],
      if (innings.isFreeHitActive) ...[
        const SizedBox(height: 6),
        Text(
          'FREE HIT',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: heroEmphasis,
            letterSpacing: 1.2,
          ),
        ),
      ],
    ];
  }
}
