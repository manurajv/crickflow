import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_dimens.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/match_score_display.dart';
import '../../data/models/match_model.dart';

/// Compact match row card for list screens (reference-inspired layout).
class MatchListCard extends StatelessWidget {
  const MatchListCard({
    super.key,
    required this.match,
    this.tournamentLabel,
  });

  final MatchModel match;
  final String? tournamentLabel;

  @override
  Widget build(BuildContext context) {
    final status = _statusUi(match.status);
    final meta = _metaLine(match);
    final footer = _footerLine(match);

    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceXs,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/match/${match.id}'),
        child: Padding(
          padding: AppDimens.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      tournamentLabel ?? match.title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _StatusChip(label: status.label, color: status.color),
                ],
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  meta,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              Text(
                match.teamAName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                match.teamBName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (match.status == MatchStatus.live ||
                  match.status == MatchStatus.inningsBreak) ...[
                const SizedBox(height: AppDimens.spaceSm),
                _LiveScoreLine(match: match),
              ],
              const Divider(height: AppDimens.spaceLg),
              if (footer.isNotEmpty)
                Text(
                  footer,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: AppDimens.spaceXs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _LinkButton(
                    label: 'Insights',
                    onTap: () => context.push('/match/${match.id}'),
                  ),
                  _LinkButton(
                    label: 'Scorecard',
                    onTap: () => context.push('/match/${match.id}/scorecard'),
                  ),
                  if (match.status == MatchStatus.completed)
                    _LinkButton(
                      label: 'Highlights',
                      onTap: () =>
                          context.push('/match/${match.id}/highlights'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _metaLine(MatchModel m) {
    final parts = <String>[];
    if (m.scheduledAt != null) {
      parts.add(AppDateUtils.formatShort(m.scheduledAt!));
    }
    parts.add('${m.rules.totalOvers} Ov.');
    if (m.venue.isNotEmpty) {
      parts.add(m.venue);
    } else if (m.location.displayLabel.isNotEmpty) {
      parts.add(m.location.displayLabel);
    }
    return parts.join(' | ');
  }

  String _footerLine(MatchModel m) {
    if (m.resultSummary.isNotEmpty) return m.resultSummary;
    if (m.status == MatchStatus.scheduled && m.scheduledAt != null) {
      return 'Scheduled · ${AppDateUtils.formatShort(m.scheduledAt!)}';
    }
    if (m.status == MatchStatus.live) return 'Match in progress';
    if (m.status == MatchStatus.completed) return 'Tap for full scorecard';
    return '';
  }

  ({String label, Color color}) _statusUi(MatchStatus status) {
    return switch (status) {
      MatchStatus.live || MatchStatus.inningsBreak => (
          label: 'Live',
          color: AppColors.liveIndicator,
        ),
      MatchStatus.scheduled ||
      MatchStatus.tossCompleted ||
      MatchStatus.draft => (
          label: 'Upcoming',
          color: AppColors.gold,
        ),
      MatchStatus.completed => (
          label: 'Result',
          color: AppColors.primaryBlueLight,
        ),
      MatchStatus.abandoned => (
          label: 'Abandoned',
          color: AppColors.textMuted,
        ),
    };
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
      ),
    );
  }
}

class _LiveScoreLine extends StatelessWidget {
  const _LiveScoreLine({required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final line = MatchScoreDisplay.liveScoreSubtitle(match);
    if (line == null) return const SizedBox.shrink();
    return Text(
      line,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.gold,
          ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.primaryBlueLight,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
