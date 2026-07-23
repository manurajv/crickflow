import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../data/models/user_model.dart';
import '../../../../data/models/opportunity_post_model.dart';
import '../../../../shared/providers/chat_provider.dart';
import '../../../../shared/providers/opportunity_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../domain/opportunity_category.dart';

Future<void> showOpportunityAuthorSheet(
  BuildContext context,
  String authorId,
) {
  if (authorId.isEmpty) return Future.value();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => OpportunityAuthorSheet(authorId: authorId),
  );
}

class OpportunityAuthorSheet extends ConsumerWidget {
  const OpportunityAuthorSheet({super.key, required this.authorId});

  final String authorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final userAsync = ref.watch(userProfileByIdProvider(authorId));
    final socialAsync = ref.watch(playerSocialStatsProvider(authorId));
    final postsAsync = ref.watch(authorOpportunityPostsProvider(authorId));
    final me = ref.watch(currentUserProfileProvider).valueOrNull;
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Text('Could not load profile: $e'),
          ),
          data: (user) {
            if (user == null) {
              return const Padding(
                padding: EdgeInsets.all(AppDimens.spaceLg),
                child: Text('User not found'),
              );
            }
            final photo = user.photoUrl?.trim() ?? '';
            final hasPhoto = photo.isNotEmpty;
            final followers = socialAsync.valueOrNull?.followersCount ??
                user.socialStats.followersCount;
            final location = user.location.displayLabel;
            final isMe = uid == user.id;
            final following = uid == null || isMe
                ? false
                : (ref
                        .watch(
                          isFollowingPlayerProvider((
                            followerId: uid,
                            followedId: user.id,
                          )),
                        )
                        .valueOrNull ??
                    false);

            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                AppDimens.spaceLg,
                0,
                AppDimens.spaceLg,
                AppDimens.spaceXl,
              ),
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: cf.sectionBackground,
                      backgroundImage: hasPhoto
                          ? CachedNetworkImageProvider(photo)
                          : null,
                      child: hasPhoto
                          ? null
                          : Text(
                              user.effectiveName.isNotEmpty
                                  ? user.effectiveName[0].toUpperCase()
                                  : '?',
                              style: theme.textTheme.titleLarge,
                            ),
                    ),
                    const SizedBox(width: AppDimens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.effectiveName,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.playerId != null &&
                                  user.playerId!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Icon(Icons.verified,
                                    size: 16, color: cf.accent),
                              ],
                            ],
                          ),
                          if (user.playerId != null &&
                              user.playerId!.isNotEmpty)
                            Text(
                              user.playerId!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cf.textMuted,
                              ),
                            ),
                          if (location.isNotEmpty)
                            Text(
                              location,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cf.textSecondary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user.bio.trim().isNotEmpty) ...[
                  const SizedBox(height: AppDimens.spaceMd),
                  Text(
                    user.bio.trim(),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cf.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppDimens.spaceMd),
                Row(
                  children: [
                    _StatChip(
                      label: 'Matches',
                      value: '${user.stats.matchesPlayed}',
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Followers',
                      value: '$followers',
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceMd),
                Row(
                  children: [
                    if (!isMe) ...[
                      Expanded(
                        child: FilledButton(
                          onPressed: () => requireAuthVoid(
                            context: context,
                            ref: ref,
                            action: () async {
                              final profile = me ??
                                  await ref.read(
                                    currentUserProfileProvider.future,
                                  );
                              if (profile == null) return;
                              final repo =
                                  ref.read(playerFollowRepositoryProvider);
                              if (following) {
                                await repo.unfollowPlayer(
                                  followerUserId: profile.id,
                                  followedUserId: user.id,
                                );
                              } else {
                                await repo.followPlayer(
                                  followerUserId: profile.id,
                                  followedUserId: user.id,
                                  followerPlayerId: profile.playerId ?? '',
                                  followedPlayerId: user.playerId ?? '',
                                  followerName: profile.effectiveName,
                                );
                              }
                            },
                          ),
                          child: Text(following ? 'Following' : 'Follow'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _message(context, ref, user),
                          child: const Text('Message'),
                        ),
                      ),
                    ],
                    if (!isMe) const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          final pid = user.playerId?.trim() ?? '';
                          if (pid.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile not public yet'),
                              ),
                            );
                            return;
                          }
                          Navigator.pop(context);
                          context.push('/player/$pid');
                        },
                        child: const Text('View Profile'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Text(
                  'Recent posts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceSm),
                postsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppDimens.spaceLg),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load posts: $e'),
                  data: (posts) {
                    if (posts.isEmpty) {
                      return Text(
                        'No opportunity posts yet',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cf.textMuted,
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in posts.take(5)) ...[
                          _MiniPostTile(post: p),
                          const SizedBox(height: AppDimens.spaceSm),
                        ],
                      ],
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _message(
    BuildContext context,
    WidgetRef ref,
    UserModel other,
  ) async {
    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final me = ref.read(currentUserProfileProvider).valueOrNull;
        if (me == null) return;
        try {
          final chatId =
              await ref.read(chatRepositoryProvider).openOrCreateChat(
                    me: me,
                    other: other,
                  );
          if (context.mounted) {
            Navigator.pop(context);
            context.push('/community/chats/$chatId');
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$e')),
            );
          }
        }
      },
    );
  }
}

class _MiniPostTile extends StatelessWidget {
  const _MiniPostTile({required this.post});

  final OpportunityPostModel post;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return Container(
      decoration: cfCardDecoration(context),
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.category.badgeLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: post.category.badgeColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            post.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (post.locationLabel.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.locationLabel,
              style: theme.textTheme.bodySmall?.copyWith(color: cf.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cf.sectionBackground,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
        border: Border.all(color: cf.border.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: cf.textMuted),
          ),
        ],
      ),
    );
  }
}
