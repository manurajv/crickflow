import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/match_card_navigation.dart';
import '../../../../data/models/community_post_model.dart';
import '../../../../data/models/team_model.dart';
import '../../../../data/models/tournament_model.dart';
import '../../../../data/models/user_model.dart';
import '../../../../domain/scoring/match_lifecycle.dart';
import '../../../../domain/services/player_cricket_profile_models.dart';
import '../../../../features/community/community_post_ui.dart';
import '../../../../shared/providers/player_cricket_profile_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../../../shared/widgets/match_card_ui.dart';
import '../../../../shared/widgets/match_team_avatar.dart';
import '../../../../shared/widgets/player_cluster_text.dart';
import '../../data/unified_search_service.dart';
import '../../domain/search_models.dart';

class SearchResultCard extends ConsumerWidget {
  const SearchResultCard({super.key, required this.hit});

  final UnifiedSearchHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (hit.category) {
      SearchCategory.players => _PlayerCard(user: hit.player!),
      SearchCategory.teams => _TeamCard(team: hit.team!),
      SearchCategory.matches => _MatchCard(hit: hit),
      SearchCategory.tournaments =>
        _TournamentCard(tournament: hit.tournament!),
      SearchCategory.grounds => _GroundCard(
          name: hit.groundName ?? '',
          city: hit.groundCity ?? '',
          matchCount: hit.matchCount ?? 0,
        ),
      SearchCategory.posts => _PostCard(post: hit.post!),
      SearchCategory.all => const SizedBox.shrink(),
    };
  }
}

class _PlayerCard extends ConsumerWidget {
  const _PlayerCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final playerId = (user.playerId ?? '').trim();
    final clustersAsync = ref.watch(playerCricketProfileByIdProvider(user.id));
    final clusters =
        clustersAsync.valueOrNull?.clusters ?? const PlayerClusters();
    final locationLabel = [
      if (user.country.isNotEmpty) user.country,
      if (user.location.city.isNotEmpty) user.location.city,
    ].join(' · ');

    return _CardShell(
      onTap: () {
        if (playerId.isNotEmpty) {
          context.push('/player/$playerId');
        } else {
          context.push('/players/${user.id}');
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(url: user.photoUrl, name: user.effectiveName),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        user.effectiveName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (playerId.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        playerId,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: cf.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    locationLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cf.textSecondary,
                    ),
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: clustersAsync.when(
                    data: (_) => PlayerClusterText(
                      clusters: clusters,
                      showNewPlayerForMissing: true,
                      fontSize: 11,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const PlayerClusterText(
                      clusters: PlayerClusters(),
                      showNewPlayerForMissing: true,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamCard extends ConsumerWidget {
  const _TeamCard({required this.team});

  final TeamModel team;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    String captain = '';
    if (team.captainId != null && team.captainId!.isNotEmpty) {
      final profile =
          ref.watch(userProfileByIdProvider(team.captainId!)).valueOrNull;
      captain = profile?.effectiveName ?? '';
    }

    return _CardShell(
      onTap: () => context.push('/teams/${team.id}'),
      child: Row(
        children: [
          MatchTeamAvatar(
            name: team.name,
            logoUrl: team.profileImageUrl,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (captain.isNotEmpty) 'C: $captain',
                    if (team.location.city.isNotEmpty) team.location.city,
                    '${team.memberCount} members',
                  ].join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cf.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchCard extends ConsumerWidget {
  const _MatchCard({required this.hit});

  final UnifiedSearchHit hit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final match = hit.match!;
    final cf = context.cf;
    final isLive = MatchLifecycle.isEffectivelyLive(match);
    final status = matchStatusUi(match, cf);
    final uid = ref.watch(authStateProvider).value?.uid;

    return _CardShell(
      onTap: () => openMatchFromListCard(
        context,
        ref: ref,
        match: match,
        userId: uid,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${match.teamAName} vs ${match.teamBName}',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLive)
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: cf.statusLive,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                )
              else
                Text(
                  status.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: status.color,
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (match.venue.isNotEmpty) match.venue,
              if (match.scheduledAt != null)
                AppDateUtils.formatCardSchedule(match.scheduledAt!),
            ].join(' · '),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: cf.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _TournamentCard extends StatelessWidget {
  const _TournamentCard({required this.tournament});

  final TournamentModel tournament;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final dates = [
      if (tournament.startDate != null)
        AppDateUtils.formatShort(tournament.startDate!),
      if (tournament.endDate != null)
        AppDateUtils.formatShort(tournament.endDate!),
    ].join(' – ');

    return _CardShell(
      onTap: () => context.push('/tournaments/${tournament.id}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: tournament.bannerUrl != null &&
                    tournament.bannerUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: tournament.bannerUrl!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _BannerPlaceholder(cf: cf),
                  )
                : _BannerPlaceholder(cf: cf),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tournament.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  [
                    if (dates.isNotEmpty) dates,
                    '${tournament.teamIds.length} teams',
                  ].join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cf.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.cf});

  final CfColors cf;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      color: cf.surface,
      child: Icon(Icons.emoji_events_outlined, color: cf.textMuted),
    );
  }
}

class _GroundCard extends StatelessWidget {
  const _GroundCard({
    required this.name,
    required this.city,
    required this.matchCount,
  });

  final String name;
  final String city;
  final int matchCount;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return _CardShell(
      onTap: null,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: cf.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.stadium_outlined, color: cf.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (city.isNotEmpty) city,
                    '$matchCount hosted matches',
                  ].join(' · '),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cf.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: CachedNetworkImageProvider(url!),
      );
    }
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: cf.surface,
      child: Text(initial, style: TextStyle(color: cf.textPrimary)),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final CommunityPostModel post;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return _CardShell(
      onTap: () => context.go('/community?postId=${post.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(communityCategoryIcon(post.category), color: cf.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.title.isNotEmpty ? post.title : post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    post.authorName,
                    communityCategoryLabel(post.category),
                    if (post.createdAt != null)
                      AppDateUtils.timeAgo(post.createdAt!),
                  ].where((e) => e.isNotEmpty).join(' · '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cf.textMuted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimens.spaceMd,
        0,
        AppDimens.spaceMd,
        AppDimens.spaceSm,
      ),
      child: Material(
        color: cf.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceMd),
            child: child,
          ),
        ),
      ),
    );
  }
}
