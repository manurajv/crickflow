import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/auth/auth_gate.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/theme/cf_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/deep_link_utils.dart';
import '../../../../data/models/community_post_model.dart';
import '../../../../shared/providers/community_provider.dart';
import '../../../../shared/providers/player_social_provider.dart';
import '../../../../shared/providers/providers.dart';
import '../../community_post_ui.dart';
import 'community_comments_sheet.dart';
import 'community_media_viewer.dart';
import 'community_tournament_card.dart';

class CommunityPostCard extends ConsumerWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    required this.isOwner,
    required this.onDelete,
    required this.onHide,
    required this.onReport,
    this.onBlock,
    this.highlighted = false,
  });

  final CommunityPostModel post;
  final bool isOwner;
  final VoidCallback onDelete;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback? onBlock;
  final bool highlighted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    final liked = uid == null
        ? false
        : (ref
                .watch(
                  communityPostLikedProvider((postId: post.id, userId: uid)),
                )
                .valueOrNull ??
            false);
    final saved = uid == null
        ? false
        : (ref
                .watch(
                  communityPostSavedProvider((postId: post.id, userId: uid)),
                )
                .valueOrNull ??
            false);

    final isSponsored = post.isSponsored || post.isAdminPost;
    final loc = post.location.displayLabel;

    return Container(
      decoration: BoxDecoration(
        color: isSponsored
            ? cf.accent.withValues(alpha: 0.06)
            : cf.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlighted
              ? cf.accent
              : isSponsored
                  ? cf.accent.withValues(alpha: 0.35)
                  : cf.border.withValues(alpha: 0.55),
          width: highlighted ? 1.5 : 1,
        ),
      ),
      padding: AppDimens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSponsored)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                post.isAdminPost ? 'Announcement' : 'Sponsored',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cf.accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          _Header(
            post: post,
            locationLabel: loc,
            isOwner: isOwner,
            currentUserId: uid,
            onDelete: onDelete,
            onHide: onHide,
            onReport: onReport,
            onBlock: onBlock,
          ),
          if (post.title.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              post.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (post.body.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(post.body, style: theme.textTheme.bodyMedium),
          ],
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _MediaBlock(media: post.media),
          ],
          if (post.hasTournamentEmbed) ...[
            const SizedBox(height: 12),
            CommunityTournamentCard(
              snapshot: post.tournamentSnapshot!,
              onShare: () => _share(ref),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                communityCategoryIcon(post.category),
                size: 14,
                color: cf.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                communityCategoryLabel(post.category),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: cf.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          _Actions(
            post: post,
            liked: liked,
            saved: saved,
            onLike: () => requireAuthVoid(
              context: context,
              ref: ref,
              action: () async {
                final id = ref.read(authStateProvider).valueOrNull?.uid;
                final me = ref.read(currentUserProfileProvider).valueOrNull;
                if (id == null) return;
                await ref.read(communityRepositoryProvider).toggleLike(
                      postId: post.id,
                      userId: id,
                      actorName: me?.effectiveName,
                    );
              },
            ),
            onComment: () => showCommunityCommentsSheet(
              context,
              postId: post.id,
            ),
            onShare: () => _share(ref),
            onSave: () => requireAuthVoid(
              context: context,
              ref: ref,
              action: () async {
                final id = ref.read(authStateProvider).valueOrNull?.uid;
                if (id == null) return;
                await ref.read(communityRepositoryProvider).toggleSave(
                      postId: post.id,
                      userId: id,
                    );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _share(WidgetRef ref) async {
    final url = DeepLinkUtils.hostedCommunityPostUri(post.id).toString();
    final text = post.title.isNotEmpty
        ? '${post.title}\n$url'
        : '${post.body}\n$url';
    await Share.share(text.trim());
    await ref.read(communityRepositoryProvider).incrementShareCount(post.id);
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.post,
    required this.locationLabel,
    required this.isOwner,
    required this.currentUserId,
    required this.onDelete,
    required this.onHide,
    required this.onReport,
    this.onBlock,
  });

  final CommunityPostModel post;
  final String locationLabel;
  final bool isOwner;
  final String? currentUserId;
  final VoidCallback onDelete;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final showFollow = currentUserId != null &&
        currentUserId != post.authorId &&
        post.authorId.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            if (post.authorPlayerId != null &&
                post.authorPlayerId!.isNotEmpty) {
              context.push('/player/${post.authorPlayerId}');
            }
          },
          child: CircleAvatar(
            radius: 22,
            backgroundColor: cf.sectionBackground,
            backgroundImage: post.authorPhotoUrl != null
                ? CachedNetworkImageProvider(post.authorPhotoUrl!)
                : null,
            child: post.authorPhotoUrl == null
                ? Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                  )
                : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.authorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (post.authorVerified) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified, size: 16, color: cf.accent),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (post.authorPlayerId != null &&
                      post.authorPlayerId!.isNotEmpty)
                    post.authorPlayerId!,
                  if (post.createdAt != null)
                    AppDateUtils.timeAgo(post.createdAt!),
                  if (locationLabel.isNotEmpty) locationLabel,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(color: cf.textMuted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (showFollow)
          _CompactFollow(
            authorId: post.authorId,
            authorPlayerId: post.authorPlayerId ?? '',
            authorName: post.authorName,
            followerUserId: currentUserId!,
          ),
        PopupMenuButton<String>(
          onSelected: (v) {
            switch (v) {
              case 'hide':
                onHide();
              case 'report':
                onReport();
              case 'block':
                onBlock?.call();
              case 'delete':
                onDelete();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'hide', child: Text('Hide post')),
            if (!isOwner) ...[
              const PopupMenuItem(value: 'report', child: Text('Report')),
              if (onBlock != null)
                const PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
            if (isOwner)
              const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
    );
  }
}

class _CompactFollow extends ConsumerWidget {
  const _CompactFollow({
    required this.authorId,
    required this.authorPlayerId,
    required this.authorName,
    required this.followerUserId,
  });

  final String authorId;
  final String authorPlayerId;
  final String authorName;
  final String followerUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(
      isFollowingPlayerProvider((
        followerId: followerUserId,
        followedId: authorId,
      )),
    );
    final following = followingAsync.valueOrNull ?? false;
    if (following) return const SizedBox.shrink();

    return TextButton(
      onPressed: () => requireAuthVoid(
        context: context,
        ref: ref,
        action: () async {
          final me = ref.read(currentUserProfileProvider).valueOrNull;
          await ref.read(playerFollowRepositoryProvider).followPlayer(
                followerUserId: followerUserId,
                followedUserId: authorId,
                followerPlayerId: me?.playerId ?? '',
                followedPlayerId: authorPlayerId,
                followerName: me?.effectiveName ?? 'Someone',
              );
        },
      ),
      child: const Text('Follow'),
    );
  }
}

class _MediaBlock extends StatelessWidget {
  const _MediaBlock({required this.media});

  final List<CommunityMediaItem> media;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    if (media.length == 1) {
      final item = media.first;
      return GestureDetector(
        onTap: () => openCommunityMediaViewer(context, media: media),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: item.aspectRatio,
            child: CachedNetworkImage(
              imageUrl: item.url,
              fit: BoxFit.cover,
              placeholder: (_, _) => ColoredBox(color: cf.sectionBackground),
              errorWidget: (_, _, _) => ColoredBox(
                color: cf.sectionBackground,
                child: Icon(Icons.broken_image_outlined, color: cf.textMuted),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: media.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = media[i];
          return GestureDetector(
            onTap: () => openCommunityMediaViewer(
              context,
              media: media,
              initialIndex: i,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: item.aspectRatio.clamp(0.6, 1.6),
                child: CachedNetworkImage(
                  imageUrl: item.url,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.post,
    required this.liked,
    required this.saved,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onSave,
  });

  final CommunityPostModel post;
  final bool liked;
  final bool saved;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Row(
      children: [
        _Action(
          icon: liked ? Icons.favorite : Icons.favorite_border,
          color: liked ? cf.error : null,
          label: _count(post.likeCount),
          onTap: onLike,
        ),
        _Action(
          icon: Icons.chat_bubble_outline,
          label: _count(post.commentCount),
          onTap: onComment,
        ),
        _Action(
          icon: Icons.share_outlined,
          label: _count(post.shareCount),
          onTap: onShare,
        ),
        const Spacer(),
        IconButton(
          onPressed: onSave,
          icon: Icon(
            saved ? Icons.bookmark : Icons.bookmark_border,
            color: saved ? cf.accent : null,
          ),
          tooltip: saved ? 'Saved' : 'Save',
        ),
      ],
    );
  }

  String _count(int n) => n <= 0 ? '' : '$n';
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.onTap,
    this.label = '',
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ],
        ),
      ),
    );
  }
}
