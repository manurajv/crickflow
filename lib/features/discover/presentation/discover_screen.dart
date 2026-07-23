import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/admob_config.dart';
import '../../../core/auth/auth_gate.dart';
import '../../../core/theme/app_dimens.dart';
import '../../../core/theme/cf_colors.dart';
import '../../../shared/providers/opportunity_provider.dart';
import '../../../shared/widgets/ads/cf_sticky_banner_ad.dart';
import '../../../shared/widgets/shell_tab_scaffold.dart';
import '../domain/opportunity_category.dart';
import 'create_opportunity_flow.dart';
import 'widgets/opportunity_author_sheet.dart';
import 'widgets/opportunity_post_card.dart';

/// Cricket opportunity marketplace feed.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String? _focusPostId;
  final _viewedPostIds = <String>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRouteParams());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _applyRouteParams() {
    if (!mounted) return;
    final uri = GoRouterState.of(context).uri;
    final saved = uri.queryParameters['saved'] == '1';
    final postId = uri.queryParameters['postId']?.trim();
    final filter = ref.read(opportunityFeedFilterProvider);

    if (saved && !filter.savedOnly) {
      ref.read(opportunityFeedFilterProvider.notifier).state =
          filter.copyWith(savedOnly: true);
    }
    if (postId != null && postId.isNotEmpty) {
      setState(() => _focusPostId = postId);
      ref.read(opportunityRepositoryProvider).incrementViewCount(postId);
      _viewedPostIds.add(postId);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 420) {
      ref.read(opportunityFeedControllerProvider.notifier).loadMore();
    }
  }

  void _scheduleViewIncrement(String postId) {
    if (postId.isEmpty ||
        postId == 'preview' ||
        _viewedPostIds.contains(postId)) {
      return;
    }
    _viewedPostIds.add(postId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(opportunityRepositoryProvider).incrementViewCount(postId);
    });
  }

  void _setCategory(OpportunityCategory? category) {
    final current = ref.read(opportunityFeedFilterProvider);
    ref.read(opportunityFeedFilterProvider.notifier).state = current.copyWith(
      category: category,
      clearCategory: category == null,
      quickFilterId: 'all',
    );
  }

  void _setQuickFilter(String id) {
    final current = ref.read(opportunityFeedFilterProvider);
    ref.read(opportunityFeedFilterProvider.notifier).state =
        current.copyWith(quickFilterId: id);
    if (id == 'nearby') {
      ref.read(opportunityFeedControllerProvider.notifier).resolveNearMeOrigin();
    }
  }

  void _onSearchChanged(String q) {
    final current = ref.read(opportunityFeedFilterProvider);
    ref.read(opportunityFeedFilterProvider.notifier).state =
        current.copyWith(searchQuery: q);
  }

  Future<void> _showFilterSheet() async {
    final current = ref.read(opportunityFeedFilterProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final cf = ctx.cf;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppDimens.spaceLg,
              0,
              AppDimens.spaceLg,
              AppDimens.spaceLg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Quick filters',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                for (final f in OpportunityQuickFilter.globalDefaults)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      current.quickFilterId == f.id
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: current.quickFilterId == f.id
                          ? cf.accent
                          : cf.textMuted,
                    ),
                    title: Text(f.label),
                    onTap: () => Navigator.pop(ctx, f.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (result != null) _setQuickFilter(result);
  }

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final filter = ref.watch(opportunityFeedFilterProvider);
    final feed = ref.watch(opportunityFeedControllerProvider);
    final quickFilters =
        filter.category?.quickFilters ?? OpportunityQuickFilter.globalDefaults;

    return ShellTabScaffold(
      title: Text(filter.savedOnly ? 'Saved' : 'Discover'),
      actions: [
        IconButton(
          tooltip: _searchOpen ? 'Close search' : 'Search',
          icon: Icon(_searchOpen ? Icons.close : Icons.search),
          onPressed: () {
            setState(() {
              _searchOpen = !_searchOpen;
              if (!_searchOpen) {
                _searchController.clear();
                _onSearchChanged('');
              }
            });
          },
        ),
        IconButton(
          tooltip: 'Filter',
          icon: const Icon(Icons.tune),
          onPressed: _showFilterSheet,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => requireAuthVoid(
          context: context,
          ref: ref,
          action: () => showCreateOpportunityFlow(context),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Create Post'),
      ),
      bottomNavigationBar: const CfStickyBannerAd(
        placement: AdPlacement.matchList,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(opportunityFeedControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (_searchOpen)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                    AppDimens.spaceMd,
                    0,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search opportunities…',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: const Text('All'),
                        selected: filter.category == null,
                        showCheckmark: false,
                        selectedColor: cf.accent.withValues(alpha: 0.2),
                        onSelected: (_) => _setCategory(null),
                      ),
                    ),
                    for (final c in OpportunityCategory.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.icon,
                                size: 16,
                                color: filter.category == c
                                    ? c.badgeColor
                                    : cf.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              Text(c.chipLabel),
                            ],
                          ),
                          selected: filter.category == c,
                          showCheckmark: false,
                          selectedColor: c.badgeColor.withValues(alpha: 0.18),
                          onSelected: (_) => _setCategory(c),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.spaceMd,
                    0,
                    AppDimens.spaceMd,
                    AppDimens.spaceSm,
                  ),
                  children: [
                    for (final q in quickFilters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(q.label),
                          selected: filter.quickFilterId == q.id,
                          selectedColor: cf.accent.withValues(alpha: 0.2),
                          onSelected: (_) => _setQuickFilter(q.id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (feed.loading && feed.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (feed.error != null && feed.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceLg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Could not load opportunities',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${feed.error}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cf.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceMd),
                        FilledButton(
                          onPressed: () => ref
                              .read(opportunityFeedControllerProvider.notifier)
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (feed.items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(
                  savedOnly: filter.savedOnly,
                  hasQuery: filter.searchQuery.trim().isNotEmpty,
                  onCreate: () => requireAuthVoid(
                    context: context,
                    ref: ref,
                    action: () => showCreateOpportunityFlow(
                      context,
                      initialCategory: filter.category,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.spaceMd,
                  0,
                  AppDimens.spaceMd,
                  88,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= feed.items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(AppDimens.spaceLg),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final post = feed.items[index];
                      final focused = _focusPostId == post.id;
                      _scheduleViewIncrement(post.id);
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppDimens.spaceMd),
                        child: OpportunityPostCard(
                          post: post,
                          highlighted: focused,
                          onAuthorTap: () => showOpportunityAuthorSheet(
                            context,
                            post.authorId,
                          ),
                          onTap: () {
                            setState(() => _focusPostId = post.id);
                          },
                        ),
                      );
                    },
                    childCount:
                        feed.items.length + (feed.loadingMore ? 1 : 0),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.savedOnly,
    required this.hasQuery,
    required this.onCreate,
  });

  final bool savedOnly;
  final bool hasQuery;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final cf = context.cf;
    final theme = Theme.of(context);
    final title = savedOnly
        ? 'No saved opportunities'
        : hasQuery
            ? 'No matches'
            : 'Be the first to post';
    final body = savedOnly
        ? 'Bookmark listings to find them here later.'
        : hasQuery
            ? 'Try a different search or clear filters.'
            : 'Find players, umpires, grounds, crews and more — or create a post for your cricket need.';

    return Padding(
      padding: const EdgeInsets.all(AppDimens.spaceXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.travel_explore_outlined, size: 48, color: cf.textMuted),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(color: cf.textSecondary),
            textAlign: TextAlign.center,
          ),
          if (!savedOnly && !hasQuery) ...[
            const SizedBox(height: AppDimens.spaceLg),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create Post'),
            ),
          ],
        ],
      ),
    );
  }
}
