import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/team_model.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/providers/team_join_request_provider.dart';
import '../../../../shared/providers/badge_provider.dart';
import '../utils/team_squad_utils.dart';
import 'team_invite_share_sheet.dart';
import 'team_join_action_button.dart';
import 'team_list_scope.dart';

/// Flat team row — tap row for detail, tap QR for invite sheet.
class TeamListTile extends ConsumerWidget {
  const TeamListTile({
    super.key,
    required this.team,
    this.listScope,
    this.memberTeamIds = const {},
  });

  final TeamModel team;
  final TeamListScope? listScope;
  final Set<String> memberTeamIds;

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
    final cf = context.cf;
    final theme = Theme.of(context);
    final locationLine = _locationLine;
    final captainId = team.captainId;
    final captainAsync = captainId != null && captainId.isNotEmpty
        ? ref.watch(playerDetailProvider(captainId))
        : null;
    final captainName = captainAsync?.valueOrNull?.name;
    final uid = ref.watch(authStateProvider).value?.uid;
    final canManageRequests = TeamSquadUtils.canManageJoinRequests(uid, team);
    final pendingCount = canManageRequests
        ? ref.watch(teamPendingJoinRequestsProvider(team.id)).valueOrNull?.length ??
            0
        : 0;
    final showJoin =
        listScope == TeamListScope.all &&
        uid != null &&
        !team.playerIds.contains(uid) &&
        team.createdBy != uid &&
        !TeamSquadUtils.isTeamCaptain(uid, team) &&
        !TeamSquadUtils.isTeamViceCaptain(uid, team);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push('/teams/${team.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceMd,
            AppDimens.spaceMd,
            AppDimens.spaceSm,
            AppDimens.spaceMd,
          ),
          child: Row(
            children: [
              TeamLogoAvatar(team: team, size: 52),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (pendingCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cf.error,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              pendingCount > 99 ? '99+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (locationLine != null) ...[
                      const SizedBox(height: 4),
                      _TeamMetaRow(
                        icon: Icons.place_outlined,
                        label: locationLine,
                      ),
                    ],
                    if (captainName != null && captainName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      _TeamMetaRow(badgeLabel: 'C', label: captainName),
                    ],
                  ],
                ),
              ),
              if (showJoin)
                TeamJoinActionButton(team: team, compact: true),
              IconButton(
                tooltip: 'Share team QR',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: () => showTeamInviteShareSheet(context, team),
                icon: Icon(
                  Icons.qr_code_2,
                  color: cf.accent,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared polished circular team logo widget.
///
/// Shows the team logo image when available, or a two-letter initials badge
/// with a gradient background that matches the app's cricket theme.
class TeamLogoAvatar extends StatelessWidget {
  const TeamLogoAvatar({
    super.key,
    required this.team,
    this.size = 52,
    this.borderWidth = 2.0,
  });

  final TeamModel team;
  final double size;
  final double borderWidth;

  String get _initials {
    if (team.name.isEmpty) return '?';
    final words = team.name.trim().split(RegExp(r'\s+'));
    if (words.length == 1) {
      // Single word: up to 2 chars
      return words[0].substring(0, words[0].length.clamp(0, 2)).toUpperCase();
    }
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final logoUrl = team.profileImageUrl;
    final hasImage = logoUrl != null;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasImage
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), CfColors.primaryBlue],
              ),
        color: hasImage ? cf.surfaceElevated : null,
        border: Border.all(
          color: hasImage
              ? cf.accent.withValues(alpha: 0.55)
              : CfColors.primaryBlue.withValues(alpha: 0.6),
          width: borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: cf.cardShadow,
            blurRadius: 7,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: logoUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => _Initials(
                  initials: _initials,
                  fontSize: size * 0.3,
                ),
                errorWidget: (context, url, error) => _Initials(
                  initials: _initials,
                  fontSize: size * 0.3,
                ),
              )
            : _Initials(initials: _initials, fontSize: size * 0.3),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.initials, required this.fontSize});

  final String initials;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: fontSize,
          letterSpacing: 0.5,
          height: 1,
        ),
      ),
    );
  }
}

class _TeamMetaRow extends StatelessWidget {
  const _TeamMetaRow({this.icon, this.badgeLabel, required this.label})
    : assert(icon != null || badgeLabel != null);

  final IconData? icon;
  final String? badgeLabel;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return Row(
      children: [
        if (icon != null)
          Icon(icon, size: 13, color: cf.textSecondary)
        else
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cf.accent, width: 1),
            ),
            child: Text(
              badgeLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: cf.accent,
                fontWeight: FontWeight.w700,
                fontSize: 10,
                height: 1,
              ),
            ),
          ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cf.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
