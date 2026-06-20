import 'package:flutter/material.dart';
import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/cricket_math.dart';
import '../../../../../data/models/player_model.dart';
import '../../../../../domain/services/commentary_feed_models.dart';
import '../../../../../domain/services/commentary_feed_service.dart';
import '../../../../../shared/widgets/lineup_player_avatar.dart';
import '../../../../scoring/presentation/widgets/delivery_bubble.dart';

class CommentaryContextBanner extends StatelessWidget {
  const CommentaryContextBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        border: Border(bottom: BorderSide(color: cf.border)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cf.textSecondary,
              fontSize: 12,
            ),
      ),
    );
  }
}

class CommentaryFilterBar extends StatelessWidget {
  const CommentaryFilterBar({
    super.key,
    required this.teamLabel,
    required this.filterLabel,
    required this.onTeamTap,
    required this.onFilterTap,
  });

  final String teamLabel;
  final String filterLabel;
  final VoidCallback onTeamTap;
  final VoidCallback onFilterTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      decoration: BoxDecoration(
        color: cf.card,
        border: Border(bottom: BorderSide(color: cf.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _UnderlineDropdown(
              label: teamLabel,
              onTap: onTeamTap,
            ),
          ),
          Container(width: 1, height: 36, color: cf.border),
          Expanded(
            child: _UnderlineDropdown(
              label: filterLabel,
              onTap: onFilterTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnderlineDropdown extends StatelessWidget {
  const _UnderlineDropdown({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 10,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cf.textPrimary,
                      fontSize: 14,
                    ),
              ),
            ),
            Icon(Icons.keyboard_arrow_down, color: cf.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

class CommentaryBallCard extends StatelessWidget {
  const CommentaryBallCard({
    super.key,
    required this.item,
    required this.filter,
  });

  final BallCommentaryItem item;
  final CommentaryFilter filter;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final e = item.event;
    final headline = CommentaryFeedService.sanitizeDisplayText(item.headline);
    final description =
        CommentaryFeedService.sanitizeDisplayText(item.description);
    final fielderLine =
        CommentaryFeedService.sanitizeDisplayText(item.fielderLine);
    final wicketDetail =
        CommentaryFeedService.sanitizeDisplayText(item.wicketDetailLine);

    final showWicketExtras = filter == CommentaryFilter.wickets && item.isWicket;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 38,
            child: Column(
              children: [
                Text(
                  item.ballLabel,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cf.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                DeliveryBubble(
                  event: e,
                  size: 24,
                  fontSize: 9,
                  marginRight: 0,
                ),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 44,
            margin: const EdgeInsets.only(right: 10),
            color: cf.border,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showWicketExtras) ...[
                  Text(
                    '${item.teamRuns}/${item.teamWickets}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cf.textMuted,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 2),
                ],
                _HeadlineText(text: headline, cf: cf),
                if (fielderLine.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fielderLine,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                          fontSize: 12,
                        ),
                  ),
                ],
                if (wicketDetail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    wicketDetail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                          fontSize: 11,
                        ),
                  ),
                ],
                if (filter == CommentaryFilter.full &&
                    description.isNotEmpty &&
                    !item.isWicket) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontStyle:
                              item.isBoundary ? FontStyle.italic : null,
                        ),
                  ),
                ],
                if (filter == CommentaryFilter.boundaries &&
                    description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cf.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontStyle: FontStyle.italic,
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

class _HeadlineText extends StatelessWidget {
  const _HeadlineText({required this.text, required this.cf});

  final String text;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n');
    if (parts.length < 2) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cf.textPrimary,
          height: 1.35,
        ),
      );
    }
    return RichText(
      text: TextSpan(
        style: TextStyle(fontSize: 13, color: cf.textPrimary, height: 1.3),
        children: [
          TextSpan(
            text: parts[0],
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const TextSpan(text: '\n'),
          TextSpan(
            text: parts.sublist(1).join('\n'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class CommentaryOverSummaryCard extends StatelessWidget {
  const CommentaryOverSummaryCard({
    super.key,
    required this.item,
    this.compact = false,
    this.highlighted = true,
  });

  final OverSummaryCommentaryItem item;
  final bool compact;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final wktLabel = item.wicketsInOver == 1 ? 'Wkt' : 'Wkts';
    final deliveries = item.ballEvents
        .where((e) => e.eventType != BallEventType.penalty)
        .toList();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OverBadge(
              number: item.overNumber,
              cf: cf,
              highlighted: highlighted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (highlighted)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        'END OF OVER',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: cf.accent,
                        ),
                      ),
                    ),
                  if (deliveries.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: deliveries
                            .map(
                              (e) => DeliveryBubble(
                                event: e,
                                size: 26,
                                fontSize: 9,
                                marginRight: 5,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${item.runsInOver} Runs | ${item.wicketsInOver} $wktLabel',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: highlighted
                              ? cf.textPrimary
                              : cf.textSecondary,
                          fontSize: 11,
                          fontWeight:
                              highlighted ? FontWeight.w600 : FontWeight.w400,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              '${item.teamRuns}/${item.teamWickets}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: highlighted ? cf.accent : cf.textPrimary,
                    fontSize: 15,
                  ),
            ),
          ],
        ),
        if (!compact) ...[
          const SizedBox(height: 6),
          _PlayerFiguresRow(item: item, cf: cf),
        ],
      ],
    );

    if (!highlighted) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimens.spaceMd,
          vertical: 8,
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 4,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cf.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: cf.accent.withValues(alpha: 0.28)),
        ),
        child: content,
      ),
    );
  }
}

class _OverBadge extends StatelessWidget {
  const _OverBadge({
    required this.number,
    required this.cf,
    this.highlighted = false,
  });

  final int number;
  final CfColors cf;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlighted
            ? cf.accent.withValues(alpha: 0.14)
            : cf.surfaceElevated,
        borderRadius: BorderRadius.circular(4),
        border: highlighted
            ? Border.all(color: cf.accent.withValues(alpha: 0.45))
            : null,
      ),
      child: Column(
        children: [
          Text(
            'Over',
            style: TextStyle(
              fontSize: 9,
              color: highlighted ? cf.accent : cf.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$number',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: highlighted ? cf.accent : cf.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerFiguresRow extends StatelessWidget {
  const _PlayerFiguresRow({required this.item, required this.cf});

  final OverSummaryCommentaryItem item;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    final batters = item.batters;
    return Row(
      children: [
        if (batters.isNotEmpty)
          Expanded(
            child: Text(
              batters.map((b) => '${b.name} ${b.scoreLine}').join('  '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: cf.textSecondary),
            ),
          ),
        if (batters.length > 1) const SizedBox(width: 8),
        Text(
          '${item.bowler.name} ${item.bowler.figuresLine}',
          style: TextStyle(
            fontSize: 11,
            color: cf.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Over-by-over row for the Overs filter.
class CommentaryOversRow extends StatelessWidget {
  const CommentaryOversRow({super.key, required this.item});

  final OverSummaryCommentaryItem item;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final wktLabel = item.wicketsInOver == 1 ? 'Wkt' : 'Wkts';
    final deliveries = item.ballEvents
        .where((e) => e.eventType != BallEventType.penalty)
        .toList();

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _OverBadge(number: item.overNumber, cf: cf, highlighted: true),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.bowlerToLine.isNotEmpty)
                  Text(
                    item.bowlerToLine,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: cf.textPrimary,
                      height: 1.3,
                    ),
                  ),
                if (deliveries.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: deliveries
                          .map(
                            (e) => DeliveryBubble(
                              event: e,
                              size: 28,
                              marginRight: 6,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${item.runsInOver} Runs | ${item.wicketsInOver} $wktLabel',
                  style: TextStyle(fontSize: 11, color: cf.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.teamRuns}/${item.teamWickets}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: cf.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.bowler.name} ${item.bowler.figuresLine}',
                style: TextStyle(
                  fontSize: 10,
                  color: cf.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CommentaryNextBatterCard extends StatelessWidget {
  const CommentaryNextBatterCard({
    super.key,
    required this.item,
    this.player,
  });

  final NextBatterCommentaryItem item;
  final PlayerModel? player;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final stats = player?.stats ?? const PlayerStatsModel();
    final style = player?.battingStyle.isNotEmpty == true
        ? player!.battingStyle
        : item.battingStyle;
    final name = CommentaryFeedService.sanitizeDisplayText(item.playerName);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Column(
              children: [
                Text(
                  'NEXT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: cf.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                LineupPlayerAvatar(
                  name: name,
                  photoUrl: player?.photoUrl ?? item.photoUrl,
                  radius: 22,
                ),
                const SizedBox(height: 4),
                Icon(Icons.sports_cricket, size: 14, color: cf.textMuted),
              ],
            ),
          ),
          Container(
            width: 1,
            height: 56,
            margin: const EdgeInsets.only(right: 10),
            color: cf.border,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cf.textPrimary,
                  ),
                ),
                if (style != null && style.isNotEmpty)
                  Text(
                    style,
                    style: TextStyle(
                      fontSize: 11,
                      color: cf.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (stats.matchesPlayed > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    'MAT: ${stats.matchesPlayed} | RUNS: ${stats.runs} | '
                    'AVG: ${CricketMath.battingAverage(stats.runs, stats.dismissals).toStringAsFixed(2)} | '
                    'SR: ${CricketMath.strikeRate(stats.runs, stats.ballsFaced).toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 10, color: cf.textMuted),
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

class CommentaryPowerplayCard extends StatelessWidget {
  const CommentaryPowerplayCard({super.key, required this.item});

  final MatchEventCommentaryItem item;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final title = CommentaryFeedService.sanitizeDisplayText(item.title);
    final subtitle = CommentaryFeedService.sanitizeDisplayText(item.subtitle);
    final detail = CommentaryFeedService.sanitizeDisplayText(item.detail);
    final isStarted =
        item.eventKind == CommentaryMatchEventKind.powerplayStarted;
    final isEnded = item.eventKind == CommentaryMatchEventKind.powerplayEnded;

    final accent = isStarted ? cf.statusUpcoming : cf.accent;
    final icon = isStarted ? Icons.bolt_rounded : Icons.flag_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: 4,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimens.radiusSm),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.45)),
              ),
              child: Icon(icon, size: 22, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POWERPLAY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 12,
                        color: cf.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                  if (isEnded &&
                      (item.runsScored != null ||
                          item.wicketsLost != null ||
                          item.crr != null)) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (item.runsScored != null)
                          _PowerplayStatChip(
                            icon: Icons.sports_cricket_outlined,
                            label: '${item.runsScored} Runs',
                            accent: accent,
                            cf: cf,
                          ),
                        if (item.wicketsLost != null)
                          _PowerplayStatChip(
                            icon: Icons.close_rounded,
                            label: '${item.wicketsLost} Wkts',
                            accent: accent,
                            cf: cf,
                          ),
                        if (item.crr != null)
                          _PowerplayStatChip(
                            icon: Icons.speed_rounded,
                            label: 'CRR ${item.crr!.toStringAsFixed(2)}',
                            accent: accent,
                            cf: cf,
                          ),
                      ],
                    ),
                  ],
                  if (subtitle.isNotEmpty && !isEnded) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: cf.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PowerplayStatChip extends StatelessWidget {
  const _PowerplayStatChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.cf,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cf.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cf.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class CommentaryFeedDivider extends StatelessWidget {
  const CommentaryFeedDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: context.cf.border);
  }
}
