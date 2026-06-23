import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../data/models/team_model.dart';
import '../../../../../data/models/tournament/tournament_team_request_model.dart';
import '../../../../teams/presentation/widgets/team_list_tile.dart';

class TournamentTeamCard extends StatelessWidget {  const TournamentTeamCard({
    super.key,
    required this.team,
    required this.displayStatus,
    this.captainLabel,
    this.playerCount,
    this.trailing,
    this.onTap,
  });

  final TeamModel team;
  final TournamentTeamDisplayStatus displayStatus;
  final String? captainLabel;
  final int? playerCount;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.spaceSm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: cf.border),
      ),
      child: InkWell(
        onTap: onTap ?? () => context.push('/teams/${team.id}'),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          child: Row(
            children: [
              TeamLogoAvatar(team: team, size: 48),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      team.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (captainLabel != null && captainLabel!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Captain · $captainLabel',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cf.textSecondary,
                            ),
                      ),
                    ],
                    if (playerCount != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$playerCount players',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: cf.textMuted,
                            ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TournamentTeamStatusChip(status: displayStatus),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class TournamentTeamStatusChip extends StatelessWidget {
  const TournamentTeamStatusChip({super.key, required this.status});

  final TournamentTeamDisplayStatus status;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final (color, bg) = switch (status) {
      TournamentTeamDisplayStatus.approved =>
        (cf.success, cf.success.withValues(alpha: 0.12)),
      TournamentTeamDisplayStatus.rejected =>
        (cf.error, cf.error.withValues(alpha: 0.12)),
      TournamentTeamDisplayStatus.withdrawn =>
        (cf.textMuted, cf.sectionBackground),
      TournamentTeamDisplayStatus.invited ||
      TournamentTeamDisplayStatus.pendingApproval =>
        (cf.accent, cf.accent.withValues(alpha: 0.12)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        tournamentTeamDisplayStatusLabel(status),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
