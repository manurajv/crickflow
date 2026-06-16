import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/badge_provider.dart';
import 'team_invite_share_sheet.dart';

/// Flat team row — tap row for detail, tap QR for invite sheet.
class TeamListTile extends ConsumerWidget {
  const TeamListTile({super.key, required this.team});

  final TeamModel team;

  String? get _locationLine {
    final parts = <String>[
      if (team.location.country.isNotEmpty) team.location.country,
      if (team.location.city.isNotEmpty) team.location.city,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final locationLine = _locationLine;
    final captainId = team.captainId;
    final captainAsync = captainId != null && captainId.isNotEmpty
        ? ref.watch(playerDetailProvider(captainId))
        : null;
    final captainName = captainAsync?.valueOrNull?.name;

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimens.spaceMd,
          AppDimens.spaceMd,
          AppDimens.spaceSm,
          AppDimens.spaceMd,
        ),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () => context.push('/teams/${team.id}'),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.primaryBlue,
                      backgroundImage: team.logoUrl != null
                          ? CachedNetworkImageProvider(team.logoUrl!)
                          : null,
                      child: team.logoUrl == null
                          ? Text(
                              team.name.isNotEmpty
                                  ? team.name[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (locationLine != null) ...[
                            const SizedBox(height: 4),
                            _TeamMetaRow(
                              icon: Icons.place_outlined,
                              label: locationLine,
                            ),
                          ],
                          if (captainName != null &&
                              captainName.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            _TeamMetaRow(
                              badgeLabel: 'C',
                              label: captainName,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: 'Share team QR',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: () => showTeamInviteShareSheet(context, team),
              icon: const Icon(
                Icons.qr_code_2,
                color: AppColors.gold,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMetaRow extends StatelessWidget {
  const _TeamMetaRow({
    this.icon,
    this.badgeLabel,
    required this.label,
  }) : assert(icon != null || badgeLabel != null);

  final IconData? icon;
  final String? badgeLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null)
          Icon(icon, size: 14, color: AppColors.textSecondary)
        else
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.gold, width: 1),
            ),
            child: Text(
              badgeLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.gold,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1,
              ),
            ),
          ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}
