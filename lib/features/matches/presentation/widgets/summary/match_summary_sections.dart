import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/match_share_utils.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../domain/services/match_summary_models.dart';
import '../../../../../shared/widgets/cf_button.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../../shared/widgets/match_card_ui.dart';
import '../../../../../shared/widgets/match_follow_button.dart';
import '../../../../../shared/widgets/match_quick_action_button.dart';

class SummarySectionHeader extends StatelessWidget {
  const SummarySectionHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: cf.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: TextStyle(fontSize: 12, color: cf.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class SummaryResultCard extends StatelessWidget {
  const SummaryResultCard({
    super.key,
    required this.match,
    required this.result,
    required this.isLive,
  });

  final MatchModel match;
  final MatchResultSummary result;
  final bool isLive;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final isCompleted = match.status == MatchStatus.completed;
    final views = match.stream.viewerCount;
    final status = matchStatusUi(match, cf);

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
                  child: _SummaryTeamBlock(
                    name: result.teamAName,
                    score: result.teamAScore,
                    cf: cf,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MatchStatusChip(
                      label: isLive
                          ? 'LIVE'
                          : isCompleted
                              ? 'Result'
                              : status.label,
                      color: isLive
                          ? cf.statusLive
                          : isCompleted
                              ? cf.textPrimary
                              : status.color,
                      showLivePulse: isLive,
                    ),
                    if (views > 0) ...[
                      const SizedBox(height: 6),
                      Text(
                        '$views views',
                        style: TextStyle(
                          fontSize: 12,
                          color: cf.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceMd),
            _SummaryTeamBlock(
              name: result.teamBName,
              score: result.teamBScore,
              cf: cf,
            ),
            if (result.resultLine != null && result.resultLine!.isNotEmpty) ...[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                result.resultLine!,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isCompleted || isLive ? cf.accent : cf.textPrimary,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTeamBlock extends StatelessWidget {
  const _SummaryTeamBlock({
    required this.name,
    required this.score,
    required this.cf,
  });

  final String name;
  final String? score;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final parsed = _parseScore(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: cf.textPrimary,
            letterSpacing: 0.2,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        _SummaryScoreLine(
          runsWickets: parsed.$1,
          overs: parsed.$2,
          cf: cf,
        ),
      ],
    );
  }

  (String?, String?) _parseScore(String? raw) {
    if (raw == null || raw.isEmpty) return (null, null);
    final match = RegExp(r'^(.+?)\s*\(([^)]+)\)\s*$').firstMatch(raw.trim());
    if (match != null) {
      return (match.group(1)?.trim(), match.group(2)?.trim());
    }
    return (raw.trim(), null);
  }
}

class _SummaryScoreLine extends StatelessWidget {
  const _SummaryScoreLine({
    required this.runsWickets,
    required this.overs,
    required this.cf,
  });

  final String? runsWickets;
  final String? overs;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    if (runsWickets == null) {
      return Text(
        '—',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 24,
          color: cf.textPrimary,
          height: 1,
        ),
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: runsWickets,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 24,
              color: cf.textPrimary,
              height: 1,
            ),
          ),
          if (overs != null)
            TextSpan(
              text: ' ($overs)',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: cf.textMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class SummaryInsightCard extends StatefulWidget {
  const SummaryInsightCard({super.key, required this.insight});

  final MatchInsightSummary insight;

  @override
  State<SummaryInsightCard> createState() => _SummaryInsightCardState();
}

class _SummaryInsightCardState extends State<SummaryInsightCard> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final insight = widget.insight;
    final pct = insight.contributionPercent.toStringAsFixed(2);
    final textStyle = TextStyle(
      color: cf.textSecondary,
      height: 1.45,
      fontSize: 14,
    );
    final emphasis = textStyle.copyWith(
      color: cf.textPrimary,
      fontWeight: FontWeight.w700,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimens.spaceMd),
        decoration: cfCardDecoration(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    insight.headline,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cf.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: insight.plainText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Insight copied'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.share_outlined, color: cf.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LineupPlayerAvatar(
                  name: insight.playerName,
                  photoUrl: insight.photoUrl,
                  radius: 24,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: textStyle,
                      children: [
                        if (insight.prefix.isNotEmpty)
                          TextSpan(text: insight.prefix),
                        TextSpan(text: insight.playerName, style: emphasis),
                        TextSpan(text: insight.middle),
                        TextSpan(text: '$pct%', style: emphasis),
                        TextSpan(text: insight.suffix),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                'Team effort share is based on MVP-weighted contributions from batting, bowling, and fielding.',
                style: TextStyle(fontSize: 12, color: cf.textMuted, height: 1.4),
              ),
            ],
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _snack(context, 'Thanks for your feedback'),
                  icon: Icon(Icons.thumb_up_outlined, color: cf.textSecondary, size: 20),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  onPressed: () => _snack(context, 'Feedback noted'),
                  icon: Icon(Icons.thumb_down_outlined, color: cf.textSecondary, size: 20),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  style: TextButton.styleFrom(
                    foregroundColor: cf.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(_expanded ? 'Show less' : 'Know more'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }
}

class SummaryHeroesSection extends StatelessWidget {
  const SummaryHeroesSection({super.key, required this.heroes});

  final List<SummaryHeroCard> heroes;

  @override
  Widget build(BuildContext context) {
    if (heroes.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Heroes of the Match'),
        SizedBox(
          height: 196,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            scrollDirection: Axis.horizontal,
            itemCount: heroes.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppDimens.spaceSm),
            itemBuilder: (context, index) =>
                _HeroCard(hero: heroes[index], cf: cf),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.hero, required this.cf});

  final SummaryHeroCard hero;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final accent = switch (hero.kind) {
      SummaryHeroKind.playerOfMatch => cf.accent,
      SummaryHeroKind.fighterOfMatch => cf.info,
      SummaryHeroKind.bestBatter => cf.success,
      SummaryHeroKind.bestBowler => CfColors.primaryBlue,
      SummaryHeroKind.bestFielder => cf.success,
    };

    return Container(
      width: 168,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hero.title,
            maxLines: 2,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const Spacer(),
          Center(
            child: LineupPlayerAvatar(
              name: hero.playerName,
              photoUrl: hero.photoUrl,
              radius: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hero.playerName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cf.textPrimary,
            ),
          ),
          Text(
            hero.teamName.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: cf.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (hero.primaryStatLine.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              hero.primaryStatLine,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: cf.textSecondary,
              ),
            ),
          ],
          if (hero.secondaryStatLine != null &&
              hero.secondaryStatLine!.isNotEmpty)
            Text(
              hero.secondaryStatLine!,
              style: TextStyle(fontSize: 11, color: cf.textMuted),
            ),
          const Spacer(),
          Text(
            'MVP ${hero.mvpScore.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: cf.scoreEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryStarPerformersSection extends StatelessWidget {
  const SummaryStarPerformersSection({
    super.key,
    required this.batters,
    required this.bowlers,
    required this.fielders,
    required this.allRounders,
  });

  final List<SummaryPerformerCard> batters;
  final List<SummaryPerformerCard> bowlers;
  final List<SummaryPerformerCard> fielders;
  final List<SummaryPerformerCard> allRounders;

  @override
  Widget build(BuildContext context) {
    final groups = <(String, List<SummaryPerformerCard>)>[
      if (batters.isNotEmpty) ('Top Batters', batters),
      if (bowlers.isNotEmpty) ('Top Bowlers', bowlers),
      if (fielders.isNotEmpty) ('Top Fielders', fielders),
      if (allRounders.isNotEmpty) ('Top All-rounders', allRounders),
    ];
    if (groups.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Star Performers'),
        for (final group in groups)
          _PerformerGroup(title: group.$1, performers: group.$2),
      ],
    );
  }
}

class _PerformerGroup extends StatelessWidget {
  const _PerformerGroup({required this.title, required this.performers});

  final String title;
  final List<SummaryPerformerCard> performers;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            AppDimens.spaceXs,
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cf.textSecondary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: AppDimens.spaceSm,
              crossAxisSpacing: AppDimens.spaceSm,
              childAspectRatio: 1.35,
            ),
            itemCount: performers.length,
            itemBuilder: (context, index) =>
                _PerformerTile(performer: performers[index], cf: cf),
          ),
        ),
      ],
    );
  }
}

class _PerformerTile extends StatelessWidget {
  const _PerformerTile({required this.performer, required this.cf});

  final SummaryPerformerCard performer;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceSm),
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LineupPlayerAvatar(
                name: performer.playerName,
                photoUrl: performer.photoUrl,
                radius: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      performer.playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: cf.textPrimary,
                      ),
                    ),
                    Text(
                      performer.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: cf.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            performer.statLine,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: cf.accent,
            ),
          ),
          if (performer.subtitle.isNotEmpty)
            Text(
              performer.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: cf.textSecondary),
            ),
        ],
      ),
    );
  }
}

class SummaryPartnershipCardWidget extends StatelessWidget {
  const SummaryPartnershipCardWidget({super.key, required this.partnership});

  final SummaryPartnershipCard partnership;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Best Partnership'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${partnership.runs} Runs',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cf.scoreEmphasis,
                  ),
                ),
                Text(
                  partnership.inningsLabel,
                  style: TextStyle(fontSize: 12, color: cf.textMuted),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  partnership.batterAName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _ShareBar(
                  share: partnership.batterAShare,
                  runs: partnership.batterARuns,
                  color: cf.accent,
                  cf: cf,
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  partnership.batterBName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                _ShareBar(
                  share: partnership.batterBShare,
                  runs: partnership.batterBRuns,
                  color: CfColors.primaryBlue,
                  cf: cf,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ShareBar extends StatelessWidget {
  const _ShareBar({
    required this.share,
    required this.runs,
    required this.color,
    required this.cf,
  });

  final double share;
  final int runs;
  final Color color;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: cf.sectionBackground,
              color: color,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$runs',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: cf.textSecondary,
          ),
        ),
      ],
    );
  }
}

class SummaryTimelineSection extends StatelessWidget {
  const SummaryTimelineSection({super.key, required this.events});

  final List<MatchTimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;
    final shown = events.take(12).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Match Timeline'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Container(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            decoration: cfCardDecoration(context),
            child: Column(
              children: [
                for (var i = 0; i < shown.length; i++)
                  _TimelineRow(
                    event: shown[i],
                    isLast: i == shown.length - 1,
                    cf: cf,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.isLast,
    required this.cf,
  });

  final MatchTimelineEvent event;
  final bool isLast;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: cf.accent,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: cf.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.label,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    event.detail,
                    style: TextStyle(fontSize: 12, color: cf.textSecondary),
                  ),
                  if (event.inningsLabel.isNotEmpty)
                    Text(
                      event.inningsLabel,
                      style: TextStyle(fontSize: 10, color: cf.textMuted),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryAwardsSection extends StatelessWidget {
  const SummaryAwardsSection({super.key, required this.awards});

  final List<MatchSummaryAward> awards;

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    final cf = context.cf;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Match Awards & Badges'),
        SizedBox(
          height: 118,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            scrollDirection: Axis.horizontal,
            itemCount: awards.length,
            separatorBuilder: (context, index) => const SizedBox(width: AppDimens.spaceSm),
            itemBuilder: (context, index) {
              final award = awards[index];
              return Container(
                width: 140,
                padding: const EdgeInsets.all(AppDimens.spaceSm),
                decoration: cfCardDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(award.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 4),
                    Text(
                      award.title,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      award.playerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cf.accent,
                      ),
                    ),
                    if (award.subtitle.isNotEmpty)
                      Text(
                        award.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: cf.textMuted),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class SummaryQuickActions extends StatelessWidget {
  const SummaryQuickActions({
    super.key,
    required this.matchId,
    required this.matchTitle,
    required this.onTab,
  });

  final String matchId;
  final String matchTitle;
  final void Function(String tabName) onTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SummarySectionHeader(title: 'Quick Actions'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: MatchFollowButton(
                      matchId: matchId,
                      quickAction: true,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.share_outlined,
                      label: 'Share Match',
                      onPressed: () => shareMatchLink(
                        matchId: matchId,
                        title: matchTitle,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.list_alt,
                      label: 'Scorecard',
                      onPressed: () => onTab('scorecard'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Row(
                children: [
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.insights_outlined,
                      label: 'Insights',
                      onPressed: () => onTab('insights'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.forum_outlined,
                      label: 'Comms',
                      onPressed: () => onTab('comms'),
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  Expanded(
                    child: MatchQuickActionButton(
                      icon: Icons.emoji_events_outlined,
                      label: 'MVP',
                      onPressed: () => onTab('mvp'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SummaryManageActions extends StatelessWidget {
  const SummaryManageActions({
    super.key,
    required this.canManage,
    required this.isCompleted,
    required this.isLive,
    required this.isBreak,
    required this.canNext,
    required this.onStart,
    required this.onNextInnings,
  });

  final bool canManage;
  final bool isCompleted;
  final bool isLive;
  final bool isBreak;
  final bool canNext;
  final VoidCallback onStart;
  final VoidCallback onNextInnings;

  @override
  Widget build(BuildContext context) {
    if (!canManage) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceLg,
        AppDimens.spaceMd,
        0,
      ),
      child: Wrap(
        spacing: AppDimens.spaceSm,
        runSpacing: AppDimens.spaceSm,
        children: [
          if (!isCompleted && !isLive && !isBreak)
            CfButton(
              label: 'Start Scoring',
              icon: Icons.play_arrow,
              onPressed: onStart,
            ),
          if (isBreak && canNext && !isCompleted)
            CfButton(
              label: 'Start 2nd Innings',
              icon: Icons.skip_next,
              isGold: true,
              onPressed: onNextInnings,
            ),
        ],
      ),
    );
  }
}

class SummaryExtrasPanel extends StatelessWidget {
  const SummaryExtrasPanel({
    super.key,
    required this.matchId,
    required this.showStream,
    required this.webrtcEnabled,
    required this.streamUrl,
    required this.secondaryUrl,
    required this.cameraA,
    required this.cameraB,
  });

  final String matchId;
  final bool showStream;
  final bool webrtcEnabled;
  final String? streamUrl;
  final String? secondaryUrl;
  final String cameraA;
  final String cameraB;

  @override
  Widget build(BuildContext context) {
    if (!showStream) return const SizedBox.shrink();
    return Column(
      children: [
        if (streamUrl != null && streamUrl!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: CfButton(
              label: 'Watch stream',
              icon: Icons.play_circle_outline,
              isOutlined: true,
              onPressed: () {},
            ),
          ),
        if (webrtcEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceMd),
            child: CfButton(
              label: 'Low latency (beta)',
              icon: Icons.speed,
              isOutlined: true,
              onPressed: () => context.push('/match/$matchId/webrtc'),
            ),
          ),
      ],
    );
  }
}
