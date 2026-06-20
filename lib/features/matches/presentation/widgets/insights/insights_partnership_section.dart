import 'package:flutter/material.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../domain/services/match_analytics_models.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../../shared/widgets/stat_grid.dart';
import 'insights_chart_widgets.dart';

/// Professional partnership comparison view with innings selector.
class InsightsPartnershipSection extends StatefulWidget {
  const InsightsPartnershipSection({
    super.key,
    required this.groups,
    required this.match,
    required this.cf,
  });

  final List<PartnershipInningsGroup> groups;
  final MatchModel match;
  final CfColors cf;

  @override
  State<InsightsPartnershipSection> createState() =>
      _InsightsPartnershipSectionState();
}

class _InsightsPartnershipSectionState extends State<InsightsPartnershipSection> {
  int _selectedIndex = 0;

  Map<String, String?> get _photoByPlayerId {
    final photos = <String, String?>{};
    final setup = widget.match.setup;
    if (setup == null) return photos;
    for (final p in [
      ...setup.teamAPlayingPlayers,
      ...setup.teamASubstitutePlayers,
      ...setup.teamBPlayingPlayers,
      ...setup.teamBSubstitutePlayers,
    ]) {
      photos[p.id] = p.photoUrl;
    }
    return photos;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groups.isEmpty) {
      return const InsightsEmptyHint(message: 'No partnerships recorded yet');
    }

    final index = _selectedIndex.clamp(0, widget.groups.length - 1);
    final group = widget.groups[index];
    final maxRuns = group.summary.highest.clamp(1, 999999);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.groups.length > 1) ...[
          _InningsSelector(
            groups: widget.groups,
            selectedIndex: index,
            onSelected: (i) => setState(() => _selectedIndex = i),
            cf: widget.cf,
          ),
          const SizedBox(height: AppDimens.spaceMd),
        ],
        StatGrid(
          cells: [
            StatCellData(
              value: '${group.summary.highest}',
              label: 'Highest Partnership',
            ),
            StatCellData(
              value: group.summary.average.toStringAsFixed(0),
              label: 'Average Partnership',
            ),
            StatCellData(
              value: '${group.summary.count}',
              label: 'Partnerships',
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceMd),
        ...group.partnerships.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: _PartnershipCard(
              partnership: p,
              maxRunsInInnings: maxRuns,
              photoByPlayerId: _photoByPlayerId,
              cf: widget.cf,
            ),
          ),
        ),
      ],
    );
  }
}

class _InningsSelector extends StatelessWidget {
  const _InningsSelector({
    required this.groups,
    required this.selectedIndex,
    required this.onSelected,
    required this.cf,
  });

  final List<PartnershipInningsGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < groups.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  _inningsChipLabel(groups[i], i),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        selectedIndex == i ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                selected: selectedIndex == i,
                onSelected: (_) => onSelected(i),
                selectedColor: cf.accent.withValues(alpha: 0.12),
                checkmarkColor: cf.accent,
                labelStyle: TextStyle(
                  color: selectedIndex == i ? cf.accent : cf.textSecondary,
                ),
                side: BorderSide(
                  color: selectedIndex == i ? cf.accent : cf.border,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
            ),
        ],
      ),
    );
  }

  String _inningsChipLabel(PartnershipInningsGroup group, int index) {
    final ord = switch (index + 1) {
      1 => '1st Inn',
      2 => '2nd Inn',
      3 => '3rd Inn',
      _ => '${index + 1}th Inn',
    };
    final short = _shortTeamName(group.label);
    return short.isNotEmpty ? '$short ($ord)' : ord;
  }

  String _shortTeamName(String name) {
    if (name.length <= 4) return name;
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length > 1) {
      return words.map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    }
    return name.substring(0, 3).toUpperCase();
  }
}

class _PartnershipCard extends StatelessWidget {
  const _PartnershipCard({
    required this.partnership,
    required this.maxRunsInInnings,
    required this.photoByPlayerId,
    required this.cf,
  });

  final PartnershipAnalytics partnership;
  final int maxRunsInInnings;
  final Map<String, String?> photoByPlayerId;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final p = partnership;
    final batterRunsTotal = (p.batterARuns + p.batterBRuns).clamp(1, 999999);
    final aShare = p.batterARuns / batterRunsTotal;
    final bShare = p.batterBRuns / batterRunsTotal;
    final barScale = (p.runs / maxRunsInInnings).clamp(0.15, 1.0);

    return Container(
      padding: AppDimens.cardPadding,
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.isHighest)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceSm),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cf.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: cf.success.withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 14, color: cf.success),
                    const SizedBox(width: 4),
                    Text(
                      'Highest Partnership',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cf.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            '${_ordinal(p.wicketNumber)} Wicket Partnership',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cf.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _BatterColumn(
                  name: p.batterAName,
                  runs: p.batterARuns,
                  balls: p.batterABalls,
                  photoUrl: photoByPlayerId[p.batterAId],
                  alignEnd: false,
                  cf: cf,
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Text(
                      '${p.runs} (${p.balls})',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: cf.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: barScale,
                      child: _ContributionBar(
                        leftFraction: aShare,
                        rightFraction: bShare,
                        cf: cf,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _BatterColumn(
                  name: p.batterBName,
                  runs: p.batterBRuns,
                  balls: p.batterBBalls,
                  photoUrl: photoByPlayerId[p.batterBId],
                  alignEnd: true,
                  cf: cf,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}

class _BatterColumn extends StatelessWidget {
  const _BatterColumn({
    required this.name,
    required this.runs,
    required this.balls,
    required this.photoUrl,
    required this.alignEnd,
    required this.cf,
  });

  final String name;
  final int runs;
  final int balls;
  final String? photoUrl;
  final bool alignEnd;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final cross =
        alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = alignEnd ? TextAlign.right : TextAlign.left;

    return Column(
      crossAxisAlignment: cross,
      children: [
        LineupPlayerAvatar(
          name: name.isNotEmpty ? name : '?',
          photoUrl: photoUrl,
          radius: 22,
        ),
        const SizedBox(height: 6),
        Text(
          name.isNotEmpty ? name : '—',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: cf.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: textAlign,
        ),
        const SizedBox(height: 2),
        Text(
          '$runs ($balls)',
          style: TextStyle(
            fontSize: 11,
            color: cf.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          textAlign: textAlign,
        ),
      ],
    );
  }
}

class _ContributionBar extends StatelessWidget {
  const _ContributionBar({
    required this.leftFraction,
    required this.rightFraction,
    required this.cf,
  });

  final double leftFraction;
  final double rightFraction;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final leftFlex = (leftFraction * 1000).round().clamp(1, 1000);
    final rightFlex = (rightFraction * 1000).round().clamp(1, 1000);

    return SizedBox(
      height: 8,
      child: Row(
        children: [
          Expanded(
            flex: leftFlex,
            child: Container(
              decoration: BoxDecoration(
                color: cf.accent,
                borderRadius: BorderRadius.horizontal(
                  left: const Radius.circular(4),
                  right: rightFlex <= 0 ? const Radius.circular(4) : Radius.zero,
                ),
              ),
            ),
          ),
          if (leftFlex > 0 && rightFlex > 0) const SizedBox(width: 2),
          Expanded(
            flex: rightFlex,
            child: Container(
              decoration: BoxDecoration(
                color: cf.accent.withValues(alpha: 0.35),
                borderRadius: BorderRadius.horizontal(
                  left: leftFlex <= 0 ? const Radius.circular(4) : Radius.zero,
                  right: const Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
