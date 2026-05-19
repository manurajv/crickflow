import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/community_post_model.dart';
import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../community_post_ui.dart';
import 'create_community_post_sheet.dart';

/// Recruitment & network posts from Firestore `community_posts`.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteCategory();
  }

  void _applyRouteCategory() {
    final raw = GoRouterState.of(context).uri.queryParameters['category'];
    if (raw == null || raw.isEmpty) return;

    CommunityPostCategory? category;
    for (final c in CommunityPostCategory.values) {
      if (c.name == raw) {
        category = c;
        break;
      }
    }
    if (category == null) return;

    final current = ref.read(communityFeedFilterProvider);
    if (current.category == category) return;
    ref.read(communityFeedFilterProvider.notifier).state =
        current.copyWith(category: category);
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(communityPostsProvider);
    final filter = ref.watch(communityFeedFilterProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final userId = ref.watch(authStateProvider).valueOrNull?.uid;

    return ShellTabScaffold(
      title: const Text('Community'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'New post',
          onPressed: () => showCreateCommunityPostSheet(
            context,
            initialCategory: filter.category,
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceMd,
              AppDimens.spaceSm,
              AppDimens.spaceMd,
              0,
            ),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected:
                      filter.category == null && !filter.nearMeOnly,
                  onSelected: (_) {
                    ref.read(communityFeedFilterProvider.notifier).state =
                        const CommunityFeedFilter();
                  },
                ),
                const SizedBox(width: AppDimens.spaceXs),
                FilterChip(
                  label: Text(
                    profile?.location.city.isNotEmpty == true
                        ? 'Near ${profile!.location.city}'
                        : 'Near me',
                  ),
                  selected: filter.nearMeOnly,
                  onSelected: (on) {
                    ref.read(communityFeedFilterProvider.notifier).state =
                        filter.copyWith(nearMeOnly: on);
                  },
                ),
                if (filter.category != null) ...[
                  const SizedBox(width: AppDimens.spaceXs),
                  FilterChip(
                    label: Text(communityCategoryLabel(filter.category!)),
                    selected: true,
                    onSelected: (_) {},
                    onDeleted: () {
                      ref.read(communityFeedFilterProvider.notifier).state =
                          filter.copyWith(clearCategory: true);
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: postsAsync.when(
              data: (posts) {
                if (posts.isEmpty) {
                  return _EmptyFeed(
                    onPost: () => showCreateCommunityPostSheet(context),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(communityPostsProvider);
                  },
                  child: ListView.separated(
                    padding: AppDimens.listPadding,
                    itemCount: posts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimens.spaceSm),
                    itemBuilder: (context, i) => _PostCard(
                      post: posts[i],
                      isOwner: userId == posts[i].authorId,
                      onDelete: () => _deletePost(posts[i].id),
                    ),
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: AppDimens.listPadding,
                  child: Text('Could not load posts: $e'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePost(String postId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete post?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(communityRepositoryProvider).deletePost(postId);
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onPost});

  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: AppDimens.listPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: AppColors.primaryBlueLight.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'No posts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              'Recruit scorers, find players, or share a practice slot in your city.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton.icon(
              onPressed: onPost,
              icon: const Icon(Icons.add),
              label: const Text('Create first post'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.isOwner,
    required this.onDelete,
  });

  final CommunityPostModel post;
  final bool isOwner;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final loc = post.location.displayLabel;

    return Card(
      child: Padding(
        padding: AppDimens.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  communityCategoryIcon(post.category),
                  size: 20,
                  color: AppColors.gold,
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: Text(
                    communityCategoryLabel(post.category),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.gold,
                        ),
                  ),
                ),
                if (post.createdAt != null)
                  Text(
                    AppDateUtils.timeAgo(post.createdAt!),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppDimens.spaceXs),
            Text(
              post.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              post.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    post.authorName,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (loc.isNotEmpty)
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                if (loc.isNotEmpty)
                  Flexible(
                    child: Text(
                      loc,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
