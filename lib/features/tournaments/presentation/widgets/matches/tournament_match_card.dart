import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/enums.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/providers.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';
import '../../../../../shared/widgets/match_list_card.dart';
import '../../utils/tournament_display_utils.dart';
import '../teams/tournament_team_confirm_sheet.dart';

/// Tournament match row with round, group, venue and schedule metadata.
class TournamentMatchCard extends ConsumerWidget {
  const TournamentMatchCard({
    super.key,
    required this.match,
    required this.tournamentId,
    this.canManage = false,
  });

  final MatchModel match;
  final String tournamentId;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final group = ref.watch(
      tournamentGroupByIdProvider(
        (tournamentId: tournamentId, groupId: match.groupId),
      ),
    );
    final roundName = match.roundName?.isNotEmpty == true
        ? match.roundName!
        : ref
            .watch(
              tournamentRoundByIdProvider(
                (tournamentId: tournamentId, roundId: match.roundId),
              ),
            )
            ?.name;

    final isLive = match.status == MatchStatus.live ||
        match.status == MatchStatus.inningsBreak;
    final canDelete =
        canManage && isDeletableUpcomingMatch(match.status);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
            0,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isLive)
                      _MetaChip(
                        label: 'LIVE',
                        color: cf.statusLive,
                        filled: true,
                      ),
                    if (roundName != null && roundName.isNotEmpty)
                      _MetaChip(label: roundName, color: cf.accent),
                    if (group != null)
                      _MetaChip(label: group.name, color: cf.info),
                    if (match.venue.isNotEmpty)
                      _MetaChip(
                        label: match.venue,
                        color: cf.textSecondary,
                        icon: Icons.place_outlined,
                      ),
                    if (match.scheduledAt != null)
                      _MetaChip(
                        label:
                            '${AppDateUtils.formatCardDate(match.scheduledAt!)} · ${AppDateUtils.formatTime(match.scheduledAt!)}',
                        color: cf.textSecondary,
                        icon: Icons.schedule_outlined,
                      ),
                    _MetaChip(
                      label:
                          '${match.rules.totalOvers} ov · ${tournamentCricketMatchTypeLabel(match.rules.cricketMatchType)}',
                      color: cf.textMuted,
                    ),
                  ],
                ),
              ),
              if (canDelete)
                IconButton(
                  tooltip: 'Delete match',
                  icon: Icon(Icons.delete_outline, color: cf.error),
                  onPressed: () => _deleteMatch(context, ref),
                ),
            ],
          ),
        ),
        MatchListCard(
          match: match,
          showTournamentHeader: false,
          showRoundBadge: false,
          showQuickLinks: true,
        ),
      ],
    );
  }

  Future<void> _deleteMatch(BuildContext context, WidgetRef ref) async {
    final confirmed = await showTournamentTeamConfirmSheet(
      context: context,
      title: 'Delete match?',
      message:
          'Remove ${match.teamAName} vs ${match.teamBName} from the schedule? This cannot be undone.',
      confirmLabel: 'Delete match',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    try {
      await ref.read(tournamentRepositoryProvider).deleteTournamentMatch(
            tournamentId: tournamentId,
            matchId: match.id,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match deleted')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
