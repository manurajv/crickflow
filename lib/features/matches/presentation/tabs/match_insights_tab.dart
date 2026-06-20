import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../domain/wagon_wheel/wagon_wheel_filter.dart';
import '../../../../shared/providers/match_analytics_provider.dart';
import '../../../../shared/providers/match_summary_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/wagon_wheel_provider.dart';
import '../../../wagon_wheel/presentation/widgets/wagon_wheel_embedded_section.dart';
import '../widgets/insights/insights_chart_widgets.dart';
import '../widgets/insights/insights_manhattan_section.dart';
import '../widgets/insights/insights_partnership_section.dart';
import '../widgets/insights/insights_run_rate_section.dart';
import '../widgets/insights/insights_section_widgets.dart';
import '../widgets/insights/insights_team_comparison_section.dart';
import '../widgets/insights/insights_test_sections.dart';
import '../widgets/insights/insights_worm_section.dart';

class MatchInsightsTab extends ConsumerWidget {
  const MatchInsightsTab({super.key, required this.matchId});

  final String matchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final analytics = ref.watch(matchAnalyticsProvider(matchId));
    final teamComparison =
        ref.watch(matchSummaryProvider(matchId)).teamComparison;
    final match = ref.watch(matchProvider(matchId)).valueOrNull;
    final wwEnabled = match?.rules.wagonWheelEnabled ?? false;
    final wwData = ref.watch(
      wagonWheelAnalyticsProvider(WagonWheelFilter(matchId: matchId)),
    );

    if (!analytics.hasData) {
      return ListView(
        padding: AppDimens.listPadding,
        children: [
          if (analytics.isLive) const _LiveChip(),
          const InsightsEmptyHint(
            message: 'Insights appear once scoring starts.',
          ),
        ],
      );
    }

    final isTest = analytics.isTestMatch;
    final test = analytics.testAnalytics;

    return ListView(
      padding: AppDimens.listPadding,
      children: [
        if (analytics.isLive) const _LiveChip(),

        InsightsCollapsibleSection(
          title: 'Match Summary',
          initiallyExpanded: true,
          child: InsightsMatchSummarySection(
            summary: analytics.summary,
            dlsInfo: analytics.dlsInfo,
            penalties: analytics.penalties,
          ),
        ),

        if (teamComparison != null)
          InsightsCollapsibleSection(
            title: 'Team Comparison',
            subtitle: '${teamComparison.teamAName} vs ${teamComparison.teamBName}',
            child: InsightsTeamComparisonSection(
              comparison: teamComparison,
              cf: cf,
            ),
          ),

        if (isTest) ...[
          if (match != null)
            InsightsCollapsibleSection(
              title: 'Partnership Analysis',
              subtitle: 'Batter contribution comparison',
              initiallyExpanded: true,
              child: InsightsPartnershipSection(
                groups: analytics.partnershipGroups,
                match: match,
                cf: cf,
              ),
            ),
          if (wwEnabled) ...[
            InsightsCollapsibleSection(
              title: 'Wagon Wheel',
              subtitle: 'Shot placement map',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WagonWheelEmbeddedSection(
                    title: 'Wagon Wheel',
                    fullViewTitle: 'Match wagon wheel',
                    baseFilter: WagonWheelFilter(matchId: matchId),
                    showTitle: false,
                  ),
                ],
              ),
            ),
            InsightsCollapsibleSection(
              title: 'Scoring Areas',
              subtitle: 'Leg · Off · Straight (handedness adjusted)',
              child: InsightsScoringAreasSection(
                legSidePercent: wwData.insights.legSidePercent,
                offSidePercent: wwData.insights.offSidePercent,
                straightPercent: wwData.insights.straightPercent,
                cf: cf,
              ),
            ),
          ],
          InsightsCollapsibleSection(
            title: 'Run Rate Graph',
            subtitle: 'Cumulative run rate progression',
            child: InsightsRunRateSection(
              data: analytics.runRate,
              cf: cf,
            ),
          ),
          if (test != null && test.sessions.isNotEmpty)
            InsightsCollapsibleSection(
              title: 'Session Analysis',
              subtitle: '30-over blocks per innings',
              child: InsightsTestSessionSection(
                sessions: test.sessions,
                cf: cf,
              ),
            ),
          if (test != null && test.newBall.isNotEmpty)
            InsightsCollapsibleSection(
              title: 'New Ball Analysis',
              subtitle: 'Opening spell (first 10 overs)',
              child: InsightsTestNewBallSection(
                stats: test.newBall,
                cf: cf,
              ),
            ),
          if (test != null)
            InsightsCollapsibleSection(
              title: 'Batting Control',
              subtitle: 'Strike rate · dots · boundaries',
              child: InsightsTestBattingControlSection(
                metrics: test.battingControl,
                cf: cf,
              ),
            ),
          if (test != null)
            InsightsCollapsibleSection(
              title: 'Bowling Pressure',
              subtitle: 'Dot ball % · economy · wickets',
              child: InsightsTestBowlingPressureSection(
                metrics: test.bowlingPressure,
                cf: cf,
              ),
            ),
          InsightsCollapsibleSection(
            title: 'Worm Graph',
            subtitle: 'Score progression by over',
            child: InsightsWormSection(
              data: analytics.worm,
              cf: cf,
              isTestMatch: true,
            ),
          ),
          InsightsCollapsibleSection(
            title: 'Manhattan Chart',
            subtitle: 'Over-by-over run comparison',
            child: InsightsManhattanSection(
              data: analytics.manhattan,
              cf: cf,
              ballsPerOver: analytics.ballsPerOver,
              isTestMatch: true,
            ),
          ),
        ] else ...[
          InsightsCollapsibleSection(
            title: 'Worm Graph',
            subtitle: 'Score progression by over',
            child: InsightsWormSection(
              data: analytics.worm,
              cf: cf,
              phaseRanges: analytics.phaseRanges,
            ),
          ),
          InsightsCollapsibleSection(
            title: 'Run Rate Graph',
            subtitle: 'Cumulative run rate progression',
            child: InsightsRunRateSection(
              data: analytics.runRate,
              cf: cf,
              phaseRanges: analytics.phaseRanges,
            ),
          ),
          InsightsCollapsibleSection(
            title: 'Manhattan Chart',
            subtitle: 'Over-by-over run comparison',
            child: InsightsManhattanSection(
              data: analytics.manhattan,
              cf: cf,
              ballsPerOver: analytics.ballsPerOver,
              phaseRanges: analytics.phaseRanges,
            ),
          ),
          if (wwEnabled) ...[
            InsightsCollapsibleSection(
              title: 'Wagon Wheel',
              subtitle: 'Shot placement map',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WagonWheelEmbeddedSection(
                    title: 'Wagon Wheel',
                    fullViewTitle: 'Match wagon wheel',
                    baseFilter: WagonWheelFilter(matchId: matchId),
                    showTitle: false,
                  ),
                ],
              ),
            ),
            InsightsCollapsibleSection(
              title: 'Scoring Areas',
              subtitle: 'Leg · Off · Straight (handedness adjusted)',
              child: InsightsScoringAreasSection(
                legSidePercent: wwData.insights.legSidePercent,
                offSidePercent: wwData.insights.offSidePercent,
                straightPercent: wwData.insights.straightPercent,
                cf: cf,
              ),
            ),
          ],
          if (match != null)
            InsightsCollapsibleSection(
              title: 'Partnership Analysis',
              subtitle: 'Batter contribution comparison',
              child: InsightsPartnershipSection(
                groups: analytics.partnershipGroups,
                match: match,
                cf: cf,
              ),
            ),
          InsightsCollapsibleSection(
            title: 'Phase Analysis',
            subtitle: analytics.phaseRanges == null
                ? 'Powerplay · Middle · Death'
                : '${analytics.phaseRanges!.powerplayLabel} · ${analytics.phaseRanges!.deathLabel}',
            child: InsightsPhaseSection(phases: analytics.phases, cf: cf),
          ),
        ],

        InsightsCollapsibleSection(
          title: 'Boundary Analysis',
          child: InsightsBoundarySection(data: analytics.boundaries, cf: cf),
        ),

        InsightsCollapsibleSection(
          title: 'Bowling Impact',
          subtitle: 'Top 5 by impact score',
          child: InsightsBowlingImpactSection(
            bowlers: analytics.bowlingImpact,
            cf: cf,
          ),
        ),

        InsightsCollapsibleSection(
          title: 'Extras Breakdown',
          child: InsightsExtrasSection(data: analytics.extras, cf: cf),
        ),

        InsightsCollapsibleSection(
          title: 'Dot Ball Analysis',
          child: InsightsDotBallSection(data: analytics.dotBalls, cf: cf),
        ),
      ],
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip();

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cf.statusLive,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'LIVE',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            'Updating with each ball',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
