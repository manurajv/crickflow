import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../shared/providers/player_social_provider.dart';
import 'player_card_tile.dart';

class ProfileConnectionsSection extends ConsumerWidget {
  const ProfileConnectionsSection({
    super.key,
    required this.user,
    required this.isOwnProfile,
    this.viewerId,
  });

  final UserModel user;
  final bool isOwnProfile;
  final String? viewerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final playerId = user.playerId ?? '';
    final followers =
        ref.watch(playerFollowersProvider(user.id)).valueOrNull ?? [];
    final following =
        ref.watch(playerFollowingProvider(user.id)).valueOrNull ?? [];
    final suggested = isOwnProfile
        ? ref.watch(suggestedPlayersProvider).valueOrNull ?? []
        : <UserModel>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Connections',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: cf.textPrimary,
                    ),
              ),
            ),
            TextButton(
              onPressed: playerId.isEmpty
                  ? null
                  : () => context.push('/find-cricketers'),
              child: const Text('Find Cricketers'),
            ),
          ],
        ),
        const SizedBox(height: AppDimens.spaceSm),
        _PreviewStrip(
          title: 'Followers',
          users: followers.take(8).toList(),
          onViewAll: playerId.isEmpty
              ? null
              : () => context.push('/player/$playerId/followers'),
          viewerId: viewerId,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        _PreviewStrip(
          title: 'Following',
          users: following.take(8).toList(),
          onViewAll: playerId.isEmpty
              ? null
              : () => context.push('/player/$playerId/following'),
          viewerId: viewerId,
        ),
        if (isOwnProfile && suggested.isNotEmpty) ...[
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            'Suggested For You',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cf.textPrimary,
                ),
          ),
          const SizedBox(height: AppDimens.spaceSm),
          ...suggested.take(3).map(
                (u) => PlayerCardTile(
                  user: u,
                  viewerId: viewerId,
                ),
              ),
        ],
      ],
    );
  }
}

class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({
    required this.title,
    required this.users,
    this.onViewAll,
    this.viewerId,
  });

  final String title;
  final List<UserModel> users;
  final VoidCallback? onViewAll;
  final String? viewerId;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: cfCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cf.textPrimary,
                      ),
                ),
              ),
              if (onViewAll != null)
                TextButton(onPressed: onViewAll, child: const Text('View All')),
            ],
          ),
          if (users.isEmpty)
            Text(
              'No $title yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cf.textMuted,
                  ),
            )
          else
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final u = users[index];
                  return _AvatarChip(user: u);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  const _AvatarChip({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final playerId = user.playerId;
    return InkWell(
      onTap: playerId == null || playerId.isEmpty
          ? null
          : () => context.push('/player/$playerId'),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: CfColors.primaryBlue,
              backgroundImage:
                  user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null
                  ? Text(
                      user.effectiveName.isNotEmpty
                          ? user.effectiveName[0].toUpperCase()
                          : '?',
                      style: TextStyle(color: cf.onPrimary),
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              user.effectiveName.split(' ').first,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cf.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
