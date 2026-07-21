import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_gate.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/chat_provider.dart';
import '../../../shared/providers/community_provider.dart';
import '../../../shared/providers/providers.dart';
import '../../../data/models/community_post_model.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../community_post_ui.dart';
import 'create_community_post_sheet.dart';
import 'widgets/community_feed_skeleton.dart';
import 'widgets/community_location_filter_sheet.dart';
import 'widgets/community_post_card.dart';

/// Social cricket community feed — extends the existing `community_posts` model.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scrollController = ScrollController();
  var _prefsHydrated = false;
  String? _focusPostId;
  CommunityPostModel? _focusPost;
  String? _handledPostId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydratePrefs();
      _applyRoutePostId();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _applyRouteCategory();
    _applyRoutePostId();
  }

  Future<void> _applyRoutePostId() async {
    final postId = GoRouterState.of(context).uri.queryParameters['postId'];
    if (postId == null || postId.isEmpty) return;
    if (_handledPostId == postId) return;
    _handledPostId = postId;
    setState(() => _focusPostId = postId);
    try {
      final post =
          await ref.read(communityRepositoryProvider).getPost(postId);
      if (!mounted) return;
      if (post != null) {
        setState(() => _focusPost = post);
      }
    } catch (_) {}
  }

  Future<void> _hydratePrefs() async {
    if (_prefsHydrated) return;
    _prefsHydrated = true;
    final locStore =
        await ref.read(communityLocationFilterStoreProvider.future);
    final hiddenStore =
        await ref.read(communityHiddenPostsStoreProvider.future);
    final locations = locStore.read();
    final hidden = hiddenStore.read();
    if (!mounted) return;
    if (locations.isNotEmpty) {
      final current = ref.read(communityFeedFilterProvider);
      ref.read(communityFeedFilterProvider.notifier).state =
          current.copyWith(locations: locations);
    }
    if (hidden.isNotEmpty) {
      ref.read(communityHiddenPostIdsProvider.notifier).state = hidden;
    }
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      ref.read(communityFeedControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _blockUser(String authorId, String authorName) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block user?'),
        content: Text(
          'Block $authorName? They will not be able to message you, and their posts will be hidden.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid == null) return;
        await ref.read(chatRepositoryProvider).blockUser(
              blockerId: uid,
              blockedId: authorId,
            );
        // Hide all currently loaded posts from this author.
        final feed = ref.read(communityFeedControllerProvider);
        for (final p in feed.items) {
          if (p.authorId == authorId) {
            await _hidePost(p.id);
          }
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Blocked $authorName')),
          );
        }
      },
    );
  }

  Future<void> _openLocationFilter() async {
    final filter = ref.read(communityFeedFilterProvider);
    final result = await showCommunityLocationFilterSheet(
      context,
      initial: filter.locations,
    );
    if (result == null || !mounted) return;
    ref.read(communityFeedFilterProvider.notifier).state =
        filter.copyWith(locations: result, nearMeOnly: false);
    final store =
        await ref.read(communityLocationFilterStoreProvider.future);
    await store.write(result);
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

  Future<void> _hidePost(String postId) async {
    final next = {...ref.read(communityHiddenPostIdsProvider), postId};
    ref.read(communityHiddenPostIdsProvider.notifier).state = next;
    final store = await ref.read(communityHiddenPostsStoreProvider.future);
    await store.hide(postId);
  }

  Future<void> _reportPost(String postId, String? authorId) async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report post'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason',
            hintText: 'Spam, harassment, misleading…',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (ok != true || reason.isEmpty || !mounted) return;

    requireAuthVoid(
      context: context,
      ref: ref,
      action: () async {
        final uid = ref.read(authStateProvider).valueOrNull?.uid;
        if (uid == null) return;
        await ref.read(communityRepositoryProvider).reportPost(
              postId: postId,
              reporterUserId: uid,
              reason: reason,
              authorId: authorId,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report submitted')),
          );
        }
        await _hidePost(postId);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(communityFeedControllerProvider);
    final filter = ref.watch(communityFeedFilterProvider);
    final profile = ref.watch(currentUserProfileProvider).valueOrNull;
    final userId = ref.watch(authStateProvider).valueOrNull?.uid;
    final cf = context.cf;
    final unreadChats =
        ref.watch(chatUnreadCountProvider).valueOrNull ?? 0;
    final requestCount =
        ref.watch(messageRequestCountProvider).valueOrNull ?? 0;
    final fabBadge = unreadChats + requestCount;

    return ShellTabScaffold(
      title: const Text('Community'),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Chats',
        onPressed: () {
          requireAuthVoid(
            context: context,
            ref: ref,
            action: () async {
              if (context.mounted) context.push('/community/chats');
            },
          );
        },
        child: Badge(
          isLabelVisible: fabBadge > 0,
          label: Text(fabBadge > 99 ? '99+' : '$fabBadge'),
          child: const Icon(Icons.chat_bubble_outline),
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search community',
          onPressed: () {
            context.push('/search');
          },
        ),
        IconButton(
          icon: Badge(
            isLabelVisible: filter.locations.isNotEmpty,
            smallSize: 8,
            child: const Icon(Icons.location_on_outlined),
          ),
          tooltip: 'Location filter',
          onPressed: _openLocationFilter,
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'New post',
          onPressed: () {
            requireAuthVoid(
              context: context,
              ref: ref,
              action: () async {
                if (context.mounted) {
                  await showCreateCommunityPostSheet(
                    context,
                    initialCategory: filter.category,
                  );
                }
              },
            );
          },
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
                  selected: filter.category == null &&
                      !filter.nearMeOnly &&
                      filter.locations.isEmpty,
                  onSelected: (_) {
                    ref.read(communityFeedFilterProvider.notifier).state =
                        const CommunityFeedFilter();
                    ref.read(communityLocationFilterStoreProvider).whenData(
                          (s) => s.clear(),
                        );
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
                if (filter.locations.isNotEmpty) ...[
                  const SizedBox(width: AppDimens.spaceXs),
                  FilterChip(
                    label: Text('${filter.locations.length} locations'),
                    selected: true,
                    onSelected: (_) => _openLocationFilter(),
                    onDeleted: () async {
                      ref.read(communityFeedFilterProvider.notifier).state =
                          filter.copyWith(locations: const []);
                      final store = await ref
                          .read(communityLocationFilterStoreProvider.future);
                      await store.clear();
                    },
                  ),
                ],
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
            child: Builder(
              builder: (context) {
                if (feed.loading && feed.items.isEmpty) {
                  return const CommunityFeedSkeleton();
                }
                if (feed.error != null && feed.items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: AppDimens.listPadding,
                      child: Text('Could not load posts: ${feed.error}'),
                    ),
                  );
                }
                if (feed.items.isEmpty && _focusPost == null) {
                  return _EmptyFeed(
                    onPost: () => showCreateCommunityPostSheet(context),
                    filtered: filter.hasLocationFilter || filter.category != null,
                  );
                }
                final items = <CommunityPostModel>[
                  if (_focusPost != null &&
                      !feed.items.any((p) => p.id == _focusPost!.id))
                    _focusPost!,
                  ...feed.items,
                ];
                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(communityFeedControllerProvider.notifier).refresh(),
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppDimens.listPadding,
                    itemCount: items.length + (feed.loadingMore ? 1 : 0),
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppDimens.spaceSm),
                    itemBuilder: (context, i) {
                      if (i >= items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(AppDimens.spaceMd),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cf.accent,
                              ),
                            ),
                          ),
                        );
                      }
                      final post = items[i];
                      return CommunityPostCard(
                        post: post,
                        isOwner: userId == post.authorId,
                        highlighted: post.id == _focusPostId,
                        onDelete: () => _deletePost(post.id),
                        onHide: () => _hidePost(post.id),
                        onReport: () =>
                            _reportPost(post.id, post.authorId),
                        onBlock: userId != null && userId != post.authorId
                            ? () => _blockUser(post.authorId, post.authorName)
                            : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed({required this.onPost, this.filtered = false});

  final VoidCallback onPost;
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    return Center(
      child: Padding(
        padding: AppDimens.listPadding,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 56,
              color: cf.accent.withValues(alpha: 0.45),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              filtered ? 'No posts match your filters' : 'No posts yet',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppDimens.spaceSm),
            Text(
              filtered
                  ? 'Try clearing location or category filters.'
                  : 'Share match moments, recruit teammates, or announce a tournament.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cf.textMuted,
                  ),
            ),
            if (!filtered) ...[
              const SizedBox(height: AppDimens.spaceLg),
              FilledButton.icon(
                onPressed: onPost,
                icon: const Icon(Icons.add),
                label: const Text('Create first post'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
