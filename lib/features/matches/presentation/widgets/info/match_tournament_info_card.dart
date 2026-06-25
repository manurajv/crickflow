import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/tournament_match_stage_utils.dart';
import '../../../../../data/models/match_model.dart';
import '../../../../../shared/providers/match_info_provider.dart';
import '../../../../../shared/providers/tournament_match_providers.dart';

/// Prominent tournament link for live, completed, and upcoming Info tabs.
class MatchTournamentInfoCard extends ConsumerWidget {
  const MatchTournamentInfoCard({super.key, required this.match});

  final MatchModel match;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tournamentId = match.tournamentId?.trim();
    if (tournamentId == null || tournamentId.isEmpty) {
      return const SizedBox.shrink();
    }

    final cf = context.cf;
    final tournamentName =
        ref.watch(matchInfoTournamentNameProvider(tournamentId)).valueOrNull;

    final resolvedRoundName = match.roundName?.trim().isNotEmpty == true
        ? match.roundName!.trim()
        : ref
            .watch(
              tournamentRoundByIdProvider(
                (tournamentId: tournamentId, roundId: match.roundId),
              ),
            )
            ?.name;

    final groupName = match.groupId != null && match.groupId!.isNotEmpty
        ? ref
            .watch(
              tournamentGroupByIdProvider(
                (tournamentId: tournamentId, groupId: match.groupId),
              ),
            )
            ?.name
        : null;

    final stageLabel = tournamentMatchStageLabel(
      match,
      roundName: resolvedRoundName,
      groupName: groupName,
    );

    final displayName = tournamentName?.trim().isNotEmpty == true
        ? tournamentName!.trim()
        : 'View tournament';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        AppDimens.spaceMd,
        0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/tournaments/$tournamentId'),
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Ink(
            decoration: BoxDecoration(
              color: cf.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: cf.accent.withValues(alpha: 0.28)),
            ),
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cf.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.emoji_events_outlined, color: cf.accent),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tournament Match',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cf.accent,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: cf.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      if (stageLabel.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          stageLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: cf.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: cf.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
