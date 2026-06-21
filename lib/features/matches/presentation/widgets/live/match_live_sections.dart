import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/match_share_utils.dart';
import '../../../../../domain/services/commentary_feed_models.dart';
import '../../../../../domain/services/match_live_models.dart';
import '../../../../../domain/services/match_summary_models.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../../shared/widgets/match_follow_button.dart';
import '../commentary/commentary_feed_widgets.dart';
import '../summary/match_summary_sections.dart';

class LiveScoreHeader extends StatelessWidget {
  const LiveScoreHeader({
    super.key,
    required this.snapshot,
    this.powerplayLabel,
  });

  final MatchLiveSnapshot snapshot;
  final String? powerplayLabel;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isBreak = snapshot.isInningsBreak;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: AppDimens.cardPadding,
        decoration: cfCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        snapshot.battingTeamName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: cf.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            snapshot.scoreLine,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: cf.textPrimary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            snapshot.oversLine,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cf.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _LiveBadge(
                  label: snapshot.statusLabel,
                  isBreak: isBreak,
                  cf: cf,
                ),
              ],
            ),
            if (powerplayLabel != null) ...[
              const SizedBox(height: 8),
              _PhaseChip(label: powerplayLabel!, cf: cf),
            ],
            if (snapshot.currentRunRate != null) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _StatChip(
                    label: 'CRR',
                    value: snapshot.currentRunRate!.toStringAsFixed(2),
                    cf: cf,
                  ),
                  if (snapshot.requiredRunRate != null)
                    _StatChip(
                      label: 'RRR',
                      value: snapshot.requiredRunRate!.toStringAsFixed(2),
                      cf: cf,
                    ),
                  if (snapshot.target != null)
                    _StatChip(
                      label: 'Target',
                      value: '${snapshot.target}',
                      cf: cf,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              LiveViewersRow(
                totalViews: snapshot.totalViews ?? 0,
                liveViewers: snapshot.liveViewers ?? 0,
              ),
            ],
            if (snapshot.chaseStatusLine != null) ...[
              const SizedBox(height: 8),
              Text(
                snapshot.chaseStatusLine!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cf.accent,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact batters / bowlers table shown under the live score header.
class LivePlayersStatsCard extends StatelessWidget {
  const LivePlayersStatsCard({
    super.key,
    required this.snapshot,
    this.onMore,
  });

  final MatchLiveSnapshot snapshot;
  final VoidCallback? onMore;

  static const _statColWidth = 36.0;
  static const _rateColWidth = 52.0;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasPlayerStats) return const SizedBox.shrink();

    final cf = context.cf;
    final labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: cf.textMuted,
    );
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cf.textMuted,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: AppDimens.spaceSm,
        ),
        decoration: cfCardDecoration(context),
        child: Column(
          children: [
            if (snapshot.batters.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: Text('Batters', style: labelStyle)),
                  _statsHeaderRow(
                    headerStyle,
                    const ['R', 'B', '4s', '6s', 'SR'],
                    rateIndex: 4,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final batter in snapshot.batters)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          batter.isStriker
                              ? '${batter.name}*'
                              : batter.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cf.accent,
                          ),
                        ),
                      ),
                      _statsValueRow(
                        cf,
                        [
                          _StatValue('${batter.runs}', bold: true),
                          _StatValue('${batter.balls}'),
                          _StatValue('${batter.fours}'),
                          _StatValue('${batter.sixes}'),
                          _StatValue(batter.strikeRate.toStringAsFixed(2), isRate: true),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
            if (_hasPartnershipRow) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Text('Partnership', style: labelStyle),
                  Text(
                    _partnershipLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (snapshot.target != null) ...[
                    Text('Target', style: labelStyle),
                    Text(
                      ' ${snapshot.target}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                  ],
                  if (onMore != null)
                    GestureDetector(
                      onTap: onMore,
                      child: Text(
                        'More',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: cf.accent,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            if (snapshot.bowlers.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(child: Text('Bowlers', style: labelStyle)),
                  _statsHeaderRow(
                    headerStyle,
                    const ['O', 'M', 'R', 'W', 'Eco'],
                    rateIndex: 4,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final bowler in snapshot.bowlers)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          bowler.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: cf.accent,
                          ),
                        ),
                      ),
                      _statsValueRow(
                        cf,
                        [
                          _StatValue(bowler.overs),
                          _StatValue('${bowler.maidens}'),
                          _StatValue('${bowler.runs}'),
                          _StatValue('${bowler.wickets}'),
                          _StatValue(
                            bowler.economy.toStringAsFixed(2),
                            isRate: true,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool get _hasPartnershipRow =>
      snapshot.partnershipRuns != null ||
      snapshot.target != null ||
      onMore != null;

  String get _partnershipLabel {
    final runs = snapshot.partnershipRuns;
    final balls = snapshot.partnershipBalls;
    if (runs == null) return '';
    if (balls != null) return ' $runs($balls)';
    return ' $runs';
  }

  Widget _statsHeaderRow(
    TextStyle style,
    List<String> labels, {
    required int rateIndex,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++)
          _headerCell(
            labels[i],
            style,
            width: i == rateIndex ? _rateColWidth : _statColWidth,
          ),
      ],
    );
  }

  Widget _statsValueRow(CfColors cf, List<_StatValue> values) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final value in values)
          _statCell(
            value.text,
            cf,
            bold: value.bold,
            width: value.isRate ? _rateColWidth : _statColWidth,
          ),
      ],
    );
  }

  Widget _headerCell(
    String label,
    TextStyle style, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }

  Widget _statCell(
    String value,
    CfColors cf, {
    bool bold = false,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Text(
        value,
        textAlign: TextAlign.center,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
          color: cf.textPrimary,
          height: 1.2,
        ),
      ),
    );
  }
}

class _StatValue {
  const _StatValue(this.text, {this.bold = false, this.isRate = false});

  final String text;
  final bool bold;
  final bool isRate;
}

class LiveInsightBanner extends StatelessWidget {
  const LiveInsightBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: cf.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: cf.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.insights_outlined, size: 18, color: cf.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cf.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveAlertsStrip extends StatelessWidget {
  const LiveAlertsStrip({super.key, required this.alerts});

  final List<LiveAlertChip> alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: alerts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final alert = alerts[index];
            final color = switch (alert.kind) {
              LiveAlertKind.wicket => cf.error,
              LiveAlertKind.boundary => cf.success,
              LiveAlertKind.partnership => CfColors.primaryBlue,
              LiveAlertKind.chase => cf.accent,
              LiveAlertKind.revision => cf.info,
              LiveAlertKind.general => cf.textSecondary,
            };
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Text(
                alert.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class LivePlayersSection extends StatelessWidget {
  const LivePlayersSection({
    super.key,
    required this.batters,
    this.bowler,
  });

  final List<LivePlayerLine> batters;
  final LiveBowlerLine? bowler;

  @override
  Widget build(BuildContext context) {
    if (batters.isEmpty && bowler == null) return const SizedBox.shrink();
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (batters.isNotEmpty) ...[
          const SummarySectionHeader(title: 'Current Batters'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              decoration: cfCardDecoration(context),
              child: Column(
                children: [
                  for (var i = 0; i < batters.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: cf.border),
                    _BatterRow(batter: batters[i], cf: cf),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (bowler != null) ...[
          const SummarySectionHeader(title: 'Current Bowler'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: cfCardDecoration(context),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bowler!.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: cf.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bowler!.figuresLine,
                          style: TextStyle(
                            fontSize: 12,
                            color: cf.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Eco ${bowler!.economy.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cf.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class LiveSnapshotSection extends StatelessWidget {
  const LiveSnapshotSection({super.key, required this.snapshot});

  final MatchLiveSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasPartnership =
        snapshot.partnershipRuns != null && snapshot.partnershipBalls != null;
    final hasTarget = snapshot.target != null;
    final hasProjected =
        snapshot.projectedScore != null || snapshot.projectedChase != null;
    if (!hasPartnership && !hasTarget && !hasProjected) {
      return const SizedBox.shrink();
    }

    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Match Snapshot'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: Row(
              children: [
                if (hasPartnership)
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Partnership',
                      value:
                          '${snapshot.partnershipRuns} (${snapshot.partnershipBalls})',
                      cf: cf,
                    ),
                  ),
                if (hasTarget)
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Target',
                      value: '${snapshot.target}',
                      cf: cf,
                    ),
                  ),
                if (snapshot.projectedScore != null)
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Projected',
                      value: '${snapshot.projectedScore}',
                      cf: cf,
                    ),
                  )
                else if (snapshot.projectedChase != null)
                  Expanded(
                    child: _SnapshotTile(
                      label: 'Projected Chase',
                      value: '${snapshot.projectedChase}',
                      cf: cf,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class LiveMilestonesSection extends StatefulWidget {
  const LiveMilestonesSection({super.key, required this.milestones});

  final List<String> milestones;

  @override
  State<LiveMilestonesSection> createState() => _LiveMilestonesSectionState();
}

class _LiveMilestonesSectionState extends State<LiveMilestonesSection> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.milestones.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceLg,
              AppDimens.spaceMd,
              AppDimens.spaceSm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Milestones',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: cf.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  color: cf.textSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimens.spaceMd),
              decoration: cfCardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < widget.milestones.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.flag_outlined, size: 16, color: cf.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.milestones[i],
                            style: TextStyle(
                              fontSize: 13,
                              color: cf.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class LiveHeroCarousel extends StatelessWidget {
  const LiveHeroCarousel({
    super.key,
    required this.heroes,
    required this.awards,
  });

  final List<SummaryHeroCard> heroes;
  final List<MatchSummaryAward> awards;

  @override
  Widget build(BuildContext context) {
    if (heroes.isEmpty && awards.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (heroes.isNotEmpty) SummaryHeroesSection(heroes: heroes),
        if (awards.isNotEmpty) SummaryAwardsSection(awards: awards),
      ],
    );
  }
}

class LiveTargetRevisionCard extends StatelessWidget {
  const LiveTargetRevisionCard({super.key, required this.info});

  final LiveTargetRevisionInfo info;

  @override
  Widget build(BuildContext context) {
    if (!info.hasData) return const SizedBox.shrink();
    final cf = context.cf;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: BoxDecoration(
          color: cf.info.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          border: Border.all(color: cf.info.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.dlsApplied ? 'DLS Target Revision' : 'Target Revision',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: cf.info,
              ),
            ),
            if (info.originalTarget != null && info.revisedTarget != null) ...[
              const SizedBox(height: 4),
              Text(
                'Original: ${info.originalTarget} → Revised: ${info.revisedTarget}',
                style: TextStyle(color: cf.textPrimary, fontSize: 13),
              ),
            ],
            if (info.penaltyRuns != null) ...[
              const SizedBox(height: 4),
              Text(
                'Penalty runs: ${info.penaltyRuns}',
                style: TextStyle(color: cf.textSecondary, fontSize: 12),
              ),
            ],
            if (info.reason != null && info.reason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                info.reason!,
                style: TextStyle(color: cf.textSecondary, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LiveActionsRow extends StatelessWidget {
  const LiveActionsRow({
    super.key,
    required this.matchId,
    required this.matchTitle,
    required this.scoreLine,
    required this.oversLine,
  });

  final String matchId;
  final String matchTitle;
  final String scoreLine;
  final String oversLine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: MatchFollowButton(matchId: matchId, quickAction: true),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: CfButton(
              label: 'Share Score',
              isOutlined: true,
              onPressed: () => shareLiveScore(
                matchId: matchId,
                title: matchTitle,
                scoreLine: '$scoreLine · $oversLine',
              ),
            ),
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: CfButton(
              label: 'Share',
              isOutlined: true,
              onPressed: () => shareMatchLink(
                matchId: matchId,
                title: matchTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveCommentarySection extends StatelessWidget {
  const LiveCommentarySection({
    super.key,
    required this.overSummary,
    required this.recentBalls,
    this.contextLine,
  });

  final OverSummaryCommentaryItem? overSummary;
  final List<CommentaryFeedItem> recentBalls;
  final String? contextLine;

  @override
  Widget build(BuildContext context) {
    if (overSummary == null && recentBalls.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Commentary'),
        if (overSummary != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: CommentaryOverSummaryCard(
              item: overSummary!,
              compact: false,
              highlighted: true,
            ),
          ),
        if (contextLine != null)
          CommentaryContextBanner(text: contextLine!),
        for (final item in recentBalls)
          if (item is BallCommentaryItem)
            CommentaryBallCard(
              item: item,
              filter: CommentaryFilter.full,
            ),
      ],
    );
  }
}

class LiveViewersRow extends StatelessWidget {
  const LiveViewersRow({
    super.key,
    required this.totalViews,
    required this.liveViewers,
  });

  final int totalViews;
  final int liveViewers;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Row(
      children: [
        _ViewMetric(value: totalViews, label: 'Total Views', cf: cf),
        Text(
          ' · ',
          style: TextStyle(fontSize: 11, color: cf.textMuted),
        ),
        _ViewMetric(value: liveViewers, label: 'Live Viewers', cf: cf),
      ],
    );
  }
}

class _ViewMetric extends StatelessWidget {
  const _ViewMetric({
    required this.value,
    required this.label,
    required this.cf,
  });

  final int value;
  final String label;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: cf.textPrimary,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: TextStyle(
              fontSize: 11,
              color: cf.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({
    required this.label,
    required this.isBreak,
    required this.cf,
  });

  final String label;
  final bool isBreak;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final color = isBreak ? cf.info : cf.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isBreak)
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: cf.error,
                shape: BoxShape.circle,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhaseChip extends StatelessWidget {
  const _PhaseChip({required this.label, required this.cf});

  final String label;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: CfColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: CfColors.primaryBlue,
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    required this.cf,
  });

  final String label;
  final String value;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(fontSize: 12, color: cf.textMuted),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: cf.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BatterRow extends StatelessWidget {
  const _BatterRow({required this.batter, required this.cf});

  final LivePlayerLine batter;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Row(
        children: [
          LineupPlayerAvatar(
            name: batter.name,
            photoUrl: batter.photoUrl,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        batter.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: cf.accent,
                        ),
                      ),
                    ),
                    if (batter.isStriker)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cf.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Striker',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: cf.accent,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${batter.scoreLine} · ${batter.fours}×4 · ${batter.sixes}×6 · SR ${batter.strikeRate.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 12, color: cf.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotTile extends StatelessWidget {
  const _SnapshotTile({
    required this.label,
    required this.value,
    required this.cf,
  });

  final String label;
  final String value;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: cf.textMuted)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: cf.textPrimary,
          ),
        ),
      ],
    );
  }
}
