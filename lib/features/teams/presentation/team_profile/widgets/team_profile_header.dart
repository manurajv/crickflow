import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../../core/theme/app_dimens.dart';
import '../../../../../core/theme/cf_colors.dart';
import '../../../../../core/utils/cf_team_id_format.dart';
import '../../../../../core/utils/deep_link_utils.dart';
import '../../../../../domain/services/team_profile/team_profile_models.dart';
import '../../../../../shared/providers/providers.dart';
import '../../utils/team_location_parts.dart';
import 'team_follow_button.dart';

/// Premium team profile hero — mirrors [CricketProfileHeader] layout language.
class TeamProfileHeader extends ConsumerWidget {
  const TeamProfileHeader({
    super.key,
    required this.snapshot,
    this.onMore,
  });

  final TeamProfileSnapshot snapshot;
  final VoidCallback? onMore;

  /// Fits identity row → social chips → actions → matches/wins/losses strip.
  static const contentHeight = 200.0;

  static double expandedHeight(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight;
    return top + contentHeight;
  }

  static Color heroBarColor(CfColors cf) => cf.heroGradient.colors.last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final team = snapshot.team;
    final stats = snapshot.stats;
    final logo = team.profileImageUrl;
    final shortName = CfTeamIdFormat.displayLabel(team.teamCode);
    final location = TeamLocationParts.fromStored(team.location)
        .teamLocation
        .displayLabel;
    final founded = team.createdAt?.year;
    final captainName = snapshot.captain == null
        ? null
        : (snapshot.captain!.fullName.trim().isNotEmpty
            ? snapshot.captain!.fullName
            : snapshot.captain!.name);
    final viewerId = ref.watch(authStateProvider).value?.uid;
    final isOwner = viewerId != null && team.createdBy == viewerId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        AppDimens.spaceSm,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'team-logo-${team.id}',
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.white24,
                  backgroundImage: logo != null && logo.isNotEmpty
                      ? CachedNetworkImageProvider(logo)
                      : null,
                  child: logo == null || logo.isEmpty
                      ? Text(
                          team.name.isNotEmpty
                              ? team.name[0].toUpperCase()
                              : 'T',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : null,
                ),
              ),
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
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (team.badgeIds.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified,
                              color: Color(0xFFFFD54F),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                    if (shortName != '—') ...[
                      const SizedBox(height: 2),
                      Text(
                        shortName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.88),
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                    if (location.isNotEmpty && location != '—') ...[
                      const SizedBox(height: 4),
                      Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (founded != null || captainName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (founded != null) 'Est. $founded',
                          if (captainName != null) 'C: $captainName',
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _HeaderStatsRow(
            followers: snapshot.followersCount,
            members: team.memberCount > 0
                ? team.memberCount
                : snapshot.players.length,
            views: team.profileViewsCount,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: [
              if (!isOwner && viewerId != null) ...[
                Expanded(
                  child: TeamFollowButton(
                    teamId: team.id,
                    teamName: team.name,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
              ],
              Expanded(
                child: _HeaderActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onPressed: () => _share(team.id, team.name),
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Expanded(
                child: _HeaderActionButton(
                  icon: Icons.more_horiz,
                  label: 'More',
                  onPressed: onMore,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          _QuickStatsStrip(stats: stats),
        ],
      ),
    );
  }

  Future<void> _share(String teamId, String name) async {
    final link = DeepLinkUtils.httpsTeamUri(teamId).toString();
    await Share.share('Check out $name on CrickFlow.\n$link');
  }
}

class _HeaderStatsRow extends StatelessWidget {
  const _HeaderStatsRow({
    required this.followers,
    required this.members,
    required this.views,
  });

  final int followers;
  final int members;
  final int views;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _chip(context, followers, 'Followers'),
        _chip(context, members, 'Members'),
        _chip(context, views, 'Views'),
      ],
    );
  }

  Widget _chip(BuildContext context, int value, String label) {
    return Column(
      children: [
        Text(
          _format(value),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.78),
                fontSize: 10,
              ),
        ),
      ],
    );
  }

  static String _format(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return '$count';
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17, color: cf.accent),
      label: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: cf.accent,
              fontWeight: FontWeight.w600,
            ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: cf.accent,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _QuickStatsStrip extends StatelessWidget {
  const _QuickStatsStrip({required this.stats});

  final TeamProfileStats stats;

  @override
  Widget build(BuildContext context) {
    final streakLabel = stats.currentStreak == 0
        ? '—'
        : stats.currentStreak > 0
            ? 'W${stats.currentStreak}'
            : 'L${-stats.currentStreak}';

    final items = [
      ('Matches', '${stats.matches}'),
      ('Wins', '${stats.wins}'),
      ('Losses', '${stats.losses}'),
      ('Ties', '${stats.ties}'),
      (
        'Win %',
        stats.matches == 0 ? '—' : stats.winPct.toStringAsFixed(1),
      ),
      ('Streak', streakLabel),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceXs,
        vertical: AppDimens.spaceSm,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 26,
                color: Colors.white.withValues(alpha: 0.25),
              ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    items[i].$2,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                  ),
                  Text(
                    items[i].$1,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 9,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
